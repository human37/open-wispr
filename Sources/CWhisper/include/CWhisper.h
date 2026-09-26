#ifndef CWHISPER_H
#define CWHISPER_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Initialize or reload the Whisper model from disk into RAM/VRAM.
/// Safe to call multiple times; if model_path is the same as the currently loaded model,
/// this is a no-op and returns true immediately.
bool cwhisper_init(const char * model_path);

/// Free the currently loaded model and release GPU/Metal resources.
void cwhisper_free(void);

/// Check if a model is currently loaded and ready for inference.
bool cwhisper_is_loaded(void);

/// Returns the file path of the currently loaded model, or NULL if none.
const char * cwhisper_current_model_path(void);

/// Transcribe 16kHz mono float32 PCM audio samples in-memory.
/// Returns a heap-allocated UTF-8 string containing the transcription.
/// The caller is responsible for freeing the string using cwhisper_free_string().
/// Returns NULL on failure.
char * cwhisper_transcribe(
    const float * samples,
    int n_samples,
    const char * language,
    const char * prompt,
    const char * suppress_regex,
    int n_threads
);

/// Free a string returned by cwhisper_transcribe().
void cwhisper_free_string(char * s);

#ifdef __cplusplus
}
#endif

#endif /* CWHISPER_H */
