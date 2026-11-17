# Phase 5 — iPhone UI and Companion

Retains shared DayMind Material UI/light+dark themes, safe-area shell, Vietnamese labels, semantics and48dp controls. Companion default80dp, configurable size/off/low-resource, PNG/JPEG/BMP/WebP/GIF/sprite import limits unchanged. Preview now hides while keyboard is visible on dashboard/Companion page. Foreground reminder fallback stays independent of whether artwork is visible. No system-wide iOS overlay, sound or standalone Companion notification; Live2D stays OFF pending SDK/build/license verification.

New iOS-target widget cases:320×568 at200% text,402×874 dark with top47/bottom34 safe area,874×402 landscape at150%. They exposed real editor overflow with keyboard; fixed adaptive dialog insets/padding and a single-line short-height heading, preserving scrollable fields and accessible save button. All3 now create tasks with keyboard visible; existing desktop/phone/theme/accessibility/navigation/calendar/notification tests retained. Local33 widget tests pass, analyze clean. These simulated viewports do not claim the user's exact latest iPhone model or native keyboard/VoiceOver acceptance.

Original DayMind calendar/sun/leaf app icon is generated from primitives by tool/generate_ios_icon.py (Pillow developer tool only; no third-party art/fonts). iOS uses DayMindIcon catalog. macOS asset compiler and real Home Screen icon remain phase6/7 checks.

Physical checklist PENDING: Dynamic Island/notch on latest actual model; native Files picker and security-scoped document import; real keyboard/rotation/VoiceOver/reduce-motion; long animation RAM/CPU/heat; photo/GIF/sprite device decode; no obscured gestures or tabs. Existing memory limits are protections, not measured iPhone performance.
