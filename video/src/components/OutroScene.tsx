import React from 'react';
import {useCurrentFrame, useVideoConfig, interpolate, spring, staticFile} from 'remotion';

export const OutroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  // Logo animation
  const logoScale = spring({
    frame: frame - 20,
    fps,
    config: {damping: 15, stiffness: 100},
  });

  // Text typing animation - "Bộ Gõ Tiếng Việt"
  const fullText = 'Bộ Gõ Tiếng Việt';
  const typingStart = 50;
  const typingSpeed = 3; // frames per character
  const visibleChars = Math.max(0, Math.floor((frame - typingStart) / typingSpeed));
  const typedText = fullText.slice(0, Math.min(visibleChars, fullText.length));

  // CTA animation
  const ctaOpacity = interpolate(frame, [100, 130], [0, 1], {
    extrapolateRight: 'clamp',
  });

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100%',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      }}
    >
      {/* Logo - using app icon */}
      <img
        src={staticFile('logo.png')}
        style={{
          width: 220,
          height: 220,
          borderRadius: 44,
          transform: `scale(${logoScale})`,
          boxShadow: '0 20px 60px rgba(238, 90, 111, 0.4)',
          marginBottom: 40,
        }}
        alt="Caffee Logo"
      />

      {/* Typing text below logo */}
      <div
        style={{
          fontSize: 90,
          fontWeight: 600,
          color: 'white',
          marginBottom: 50,
          fontFamily: 'SF Mono, Monaco, monospace',
          minHeight: 110,
        }}
      >
        {typedText}
        <span
          style={{
            display: 'inline-block',
            width: 4,
            height: 80,
            background: '#4ECDC4',
            marginLeft: 6,
            verticalAlign: 'middle',
            opacity: frame % 30 < 15 ? 1 : 0,
          }}
        />
      </div>

      {/* CTA Button */}
      <div
        style={{
          padding: '28px 70px',
          background: 'white',
          borderRadius: 100,
          fontSize: 40,
          fontWeight: 600,
          color: '#1a1a2e',
          opacity: ctaOpacity,
          boxShadow: '0 10px 40px rgba(255, 255, 255, 0.3)',
          cursor: 'pointer',
        }}
      >
        Tải về cho macOS
      </div>

      {/* Tagline */}
      <p
        style={{
          marginTop: 30,
          fontSize: 32,
          color: 'rgba(255, 255, 255, 0.6)',
          opacity: ctaOpacity,
        }}
      >
        Miễn phí • Native • Open Source
      </p>
    </div>
  );
};
