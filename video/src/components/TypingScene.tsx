import type React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";

export const TypingScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Window entrance animation
  const windowScale = spring({
    frame: frame - 10,
    fps,
    config: { damping: 20, stiffness: 150 },
  });

  // Title animation
  const titleOpacity = interpolate(frame, [20, 40], [0, 1], {
    extrapolateRight: "clamp",
  });

  // Final text to display
  const finalText = "Cà phê sữa đá Việt Nam thiệt ngon!";
  
  // Simple character-by-character typing (3 frames per char for speed)
  const typingSpeed = 3;
  const startFrame = 40;
  const visibleChars = Math.max(
    0,
    Math.min(finalText.length, Math.floor((frame - startFrame) / typingSpeed)),
  );
  const currentText = finalText.slice(0, visibleChars);

  // Key sequence that was pressed (matching the Telex input)
  // This shows what keys user actually pressed to get the Vietnamese text
  const keySequence = [
    { key: "C", at: 40 },
    { key: "a", at: 43 },
    { key: "f", at: 46 }, // Cà
    { key: "Space", at: 49 },
    { key: "p", at: 52 },
    { key: "h", at: 55 },
    { key: "e", at: 58 },
    { key: "e", at: 61 }, // phê
    { key: "Space", at: 64 },
    { key: "s", at: 67 },
    { key: "u", at: 70 },
    { key: "w", at: 73 },
    { key: "a", at: 76 },
    { key: "r", at: 79 }, // sữa
    { key: "Space", at: 82 },
    { key: "d", at: 85 },
    { key: "d", at: 88 },
    { key: "a", at: 91 },
    { key: "s", at: 94 }, // đá
    { key: "Space", at: 97 },
    { key: "V", at: 100 },
    { key: "i", at: 103 },
    { key: "e", at: 106 },
    { key: "e", at: 109 },
    { key: "t", at: 112 },
    { key: "j", at: 115 }, // Việt
    { key: "Space", at: 118 },
    { key: "N", at: 121 },
    { key: "a", at: 124 },
    { key: "m", at: 127 }, // Nam
    { key: "Space", at: 130 },
    { key: "t", at: 133 },
    { key: "h", at: 136 },
    { key: "i", at: 139 },
    { key: "e", at: 142 },
    { key: "e", at: 145 },
    { key: "t", at: 148 },
    { key: "j", at: 151 }, // thiệt
    { key: "Space", at: 154 },
    { key: "n", at: 157 },
    { key: "g", at: 160 },
    { key: "o", at: 163 },
    { key: "n", at: 166 },
    { key: "!", at: 169 }, // ngon!
  ];

  // Find current key being pressed
  let lastPressedKey = "";
  let lastKeyFrame = 0;

  for (const item of keySequence) {
    if (frame >= item.at) {
      lastPressedKey = item.key;
      lastKeyFrame = item.at;
    }
  }

  // Show key pressed popup
  const showKeyPopup =
    frame - lastKeyFrame < 15 && lastPressedKey && frame >= startFrame;
  const keyPopupOpacity = showKeyPopup
    ? interpolate(frame - lastKeyFrame, [0, 5, 10, 15], [0, 1, 1, 0], {
        extrapolateRight: "clamp",
      })
    : 0;

  // Window dimensions (fullscreen)
  const windowWidth = 1900;
  const windowHeight = 1000;

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        height: "100%",
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
          padding: "5px",
      }}
    >
      {/* Method Label */}
      <div
        style={{
          padding: "12px 32px",
          background: "#4ECDC4",
          borderRadius: 30,
          color: "white",
          fontSize: 28,
          fontWeight: 600,
          marginBottom: 30,
          opacity: titleOpacity,
          textTransform: "uppercase",
          letterSpacing: "0.1em",
        }}
      >
        Kiểu gõ Telex
      </div>

      {/* macOS Window - 2x bigger */}
      <div
        style={{
          width: windowWidth,
          height: windowHeight,
          background: "rgba(255, 255, 255, 0.95)",
          borderRadius: 12,
          boxShadow: "0 25px 80px rgba(0, 0, 0, 0.3)",
          overflow: "hidden",
          transform: `scale(${windowScale})`,
          display: "flex",
          flexDirection: "column",
          position: "relative",
        }}
      >
        {/* Window Title Bar */}
        <div
          style={{
            height: 80,
            background: "linear-gradient(180deg, #f6f6f6 0%, #e8e8e8 100%)",
            borderBottom: "1px solid rgba(0, 0, 0, 0.1)",
            display: "flex",
            alignItems: "center",
            padding: "0 30px",
            gap: 16,
          }}
        >
            <div
            style={{
              width: 24,
              height: 24,
              borderRadius: "50%",
              background: "#FF5F57",
            }}
          />
          <div
            style={{
              width: 24,
              height: 24,
              borderRadius: "50%",
              background: "#FFBD2E",
            }}
          />
          <div
            style={{
              width: 24,
              height: 24,
              borderRadius: "50%",
              background: "#28CA41",
            }}
          />
          <span
            style={{
              marginLeft: "auto",
              marginRight: "auto",
              fontSize: 22,
              color: "#666",
              fontWeight: 500,
            }}
          >
            Notes
          </span>
        </div>

        {/* Text Editor Area */}
        <div
          style={{
            flex: 1,
            padding: 80,
            fontSize: 80,
            lineHeight: 1.5,
            color: "#333",
            fontFamily: "SF Mono, Monaco, monospace",
            position: "relative",
          }}
        >
          {currentText}
          {visibleChars < finalText.length && (
            <span
              style={{
                display: "inline-block",
                width: 6,
                height: 80,
                background: "#007AFF",
                marginLeft: 6,
                verticalAlign: "middle",
                opacity: frame % 30 < 15 ? 1 : 0,
              }}
            />
          )}
        </div>

        {/* Key Pressed Popup - Bottom Right of window */}
        {showKeyPopup && (
          <div
            style={{
              position: "absolute",
              bottom: 40,
              right: 40,
              opacity: keyPopupOpacity,
            }}
          >
            <div
              style={{
                padding: "24px 48px",
                background: "rgba(0, 0, 0, 0.85)",
                borderRadius: 16,
                color: "white",
                fontSize: 48,
                fontWeight: 600,
                boxShadow: "0 4px 20px rgba(0, 0, 0, 0.3)",
                display: "flex",
                alignItems: "center",
                gap: 20,
              }}
            >
              <span style={{ color: "rgba(255,255,255,0.6)", fontSize: 24 }}>
                Key:
              </span>
              <span
                style={{
                  padding: "8px 20px",
                  background: "rgba(255,255,255,0.2)",
                  borderRadius: 10,
                  fontFamily: "SF Mono, monospace",
                }}
              >
                {lastPressedKey}
              </span>
            </div>
          </div>
        )}
      </div>

      {/* Instruction text */}
      <div
        style={{
          marginTop: 30,
          fontSize: 28,
          color: "rgba(255, 255, 255, 0.6)",
          opacity: titleOpacity,
        }}
      >
        Gõ tự nhiên, trực quan, trải nghiệm mượt mà
      </div>
    </div>
  );
};
