/* Minimal build configuration for the pinned liba52 0.7.4 sources.
 *
 * Upstream liba52 expects an autoconf-generated config.h.  The helper does not
 * use autotools, so this hand-written header supplies only the macros the
 * pinned translation units actually test.  build_arm_stack.sh copies it beside
 * the fetched sources, which stay unmodified upstream and out of version
 * control exactly like minimp3.  Keep the upstream sources pristine and adjust
 * this file instead.
 *
 * ARM Cortex-A9 is little endian, so WORDS_BIGENDIAN stays undefined.
 * LIBA52_DJBFFT and the x86 byte-swap path are deliberately not enabled.
 * ATTRIBUTE_ALIGNED_MAX matches what GCC gives us for the sample buffers.
 * HAVE_MEMALIGN is left undefined so parse.c uses plain malloc.
 */

#ifndef LIBA52_HELPER_CONFIG_H
#define LIBA52_HELPER_CONFIG_H

#define ATTRIBUTE_ALIGNED_MAX 16

#endif
