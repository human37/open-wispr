#include "CWhisper.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <whisper.h>
#include <ggml-backend.h>

static struct whisper_context * g_ctx = NULL;
static char * g_current_model_path = NULL;
static pthread_mutex_t g_mutex = PTHREAD_MUTEX_INITIALIZER;
static bool g_backends_loaded = false;

bool cwhisper_init(const char * model_path) {
    if (!model_path || strlen(model_path) == 0) {
        return false;
    }

    pthread_mutex_lock(&g_mutex);

    // Load dynamic backends (Metal, BLAS, CPU) once
    if (!g_backends_loaded) {
        ggml_backend_load_all();
        g_backends_loaded = true;
        atexit(cwhisper_free);
    }

    // If already loaded with the same model, reuse it
    if (g_ctx != NULL && g_current_model_path != NULL && strcmp(g_current_model_path, model_path) == 0) {
        pthread_mutex_unlock(&g_mutex);
        return true;
    }

    // Release existing context if changing models
    if (g_ctx != NULL) {
        whisper_free(g_ctx);
        g_ctx = NULL;
    }
    if (g_current_model_path != NULL) {
        free(g_current_model_path);
        g_current_model_path = NULL;
    }

    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = true;
    cparams.flash_attn = true;

    struct whisper_context * ctx = whisper_init_from_file_with_params(model_path, cparams);
    if (!ctx) {
        pthread_mutex_unlock(&g_mutex);
        return false;
    }

    g_ctx = ctx;
    g_current_model_path = strdup(model_path);
    pthread_mutex_unlock(&g_mutex);
    return true;
}

void cwhisper_free(void) {
    pthread_mutex_lock(&g_mutex);
    if (g_ctx != NULL) {
        whisper_free(g_ctx);
        g_ctx = NULL;
    }
    if (g_current_model_path != NULL) {
        free(g_current_model_path);
        g_current_model_path = NULL;
    }
    pthread_mutex_unlock(&g_mutex);
}

bool cwhisper_is_loaded(void) {
    pthread_mutex_lock(&g_mutex);
    bool loaded = (g_ctx != NULL);
    pthread_mutex_unlock(&g_mutex);
    return loaded;
}

const char * cwhisper_current_model_path(void) {
    return g_current_model_path;
}

char * cwhisper_transcribe(
    const float * samples,
    int n_samples,
    const char * language,
    const char * prompt,
    const char * suppress_regex,
    int n_threads
) {
    if (!samples || n_samples <= 0) {
        return NULL;
    }

    pthread_mutex_lock(&g_mutex);
    if (!g_ctx) {
        pthread_mutex_unlock(&g_mutex);
        return NULL;
    }

    // Configure greedy sampling params for lowest latency
    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.strategy = WHISPER_SAMPLING_GREEDY;
    params.n_threads = (n_threads > 0) ? n_threads : 4;
    params.no_context = true;       // Prevents hallucination repetition loops (-mc 0)
    params.no_timestamps = true;    // Clean text output (-nt)
    params.single_segment = false;
    params.print_special = false;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.suppress_nst = true;
    params.suppress_blank = true;
    params.temperature = 0.0f;
    params.no_speech_thold = 0.6f;
    // Keep whisper.cpp's default temperature fallback (0.2 steps). It only
    // re-decodes when a pass is detected as degenerate (low token entropy, i.e.
    // a repetition loop), so it costs nothing on normal dictation but is the
    // main guard against "the the the..." loops, especially on large-v3/turbo.
    params.greedy.best_of = 1;

    // Dynamic audio context scaling:
    // Whisper's encoder evaluates attention positions across all layers.
    // For 32-layer models (like large-v3-turbo), full 1500 context (30s) takes ~1150ms of encoder GPU time.
    // Setting a safe floor of 512 frames (~10.2s buffer) saves ~750ms of compute on short dictations
    // without cutting off acoustic context or causing repetition loops.
    double duration_sec = (double)n_samples / 16000.0;
    if (duration_sec < 25.0) {
        int ctx = (int)(duration_sec * 50.0) + 256;
        if (ctx < 512) ctx = 512;
        if (ctx > 1500) ctx = 1500;
        params.audio_ctx = ctx;
    }

    // Hard cap on decoded tokens per segment, scaled to audio length, so a
    // runaway decode can never produce many repetitions of the dictation.
    // Normal speech is ~3-5 tokens/s; allow generous headroom.
    double seg_sec = duration_sec < 30.0 ? duration_sec : 30.0;
    params.max_tokens = (int)(seg_sec * 10.0) + 32;

    if (language && strlen(language) > 0) {
        params.language = language;
    } else {
        params.language = "en";
    }

    if (prompt && strlen(prompt) > 0) {
        params.initial_prompt = prompt;
    }

    if (suppress_regex && strlen(suppress_regex) > 0) {
        params.suppress_regex = suppress_regex;
    }

    int ret = whisper_full(g_ctx, params, samples, n_samples);
    if (ret != 0) {
        pthread_mutex_unlock(&g_mutex);
        return NULL;
    }

    const int n_segments = whisper_full_n_segments(g_ctx);
    size_t total_len = 0;
    for (int i = 0; i < n_segments; ++i) {
        float no_speech = whisper_full_get_segment_no_speech_prob(g_ctx, i);
        if (no_speech > 0.6f) {
            continue;
        }
        const char * text = whisper_full_get_segment_text(g_ctx, i);
        if (text) {
            total_len += strlen(text);
        }
    }

    char * result = (char *)malloc(total_len + 1);
    if (!result) {
        pthread_mutex_unlock(&g_mutex);
        return NULL;
    }
    result[0] = '\0';

    for (int i = 0; i < n_segments; ++i) {
        float no_speech = whisper_full_get_segment_no_speech_prob(g_ctx, i);
        if (no_speech > 0.6f) {
            continue;
        }
        const char * text = whisper_full_get_segment_text(g_ctx, i);
        if (text) {
            strcat(result, text);
        }
    }

    pthread_mutex_unlock(&g_mutex);
    return result;
}

void cwhisper_free_string(char * s) {
    if (s) {
        free(s);
    }
}
