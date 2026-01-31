import React from 'react';
import {useCurrentFrame, useVideoConfig, interpolate, spring, staticFile} from 'remotion';

export const IntroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  // Logo animation
  const logoScale = spring({
    frame: frame - 10,
    fps,
    config: {damping: 15, stiffness: 100},
  });

  // Title animation
  const titleOpacity = interpolate(frame, [30, 60], [0, 1], {
    extrapolateRight: 'clamp',
    extrapolateLeft: 'clamp',
  });

  const subtitleOpacity = interpolate(frame, [60, 90], [0, 1], {
    extrapolateRight: 'clamp',
    extrapolateLeft: 'clamp',
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
      {/* Logo - using app icon from web directory */}
      <img
        src={staticFile('logo.png')}
        style={{
          width: 280,
          height: 280,
          borderRadius: 56,
          transform: `scale(${logoScale})`,
          boxShadow: '0 20px 60px rgba(238, 90, 111, 0.4)',
        }}
        alt="Caffee Logo"
      />

      {/* Title */}
      <h1
        style={{
          fontSize: 140,
          fontWeight: 700,
          color: 'white',
          marginTop: 50,
          marginBottom: 20,
          opacity: titleOpacity,
          letterSpacing: '-0.02em',
        }}
      >
        Caffee
      </h1>

      {/* Subtitle */}
      <p
        style={{
          fontSize: 48,
          color: 'rgba(255, 255, 255, 0.7)',
          opacity: subtitleOpacity,
          fontWeight: 400,
        }}
      >
        Bộ gõ tiếng Việt đơn giản nhất cho macOS
      </p>

      {/* Tagline */}
      <div
        style={{
          marginTop: 40,
          padding: '18px 40px',
          background: 'rgba(255, 255, 255, 0.1)',
          borderRadius: 100,
          fontSize: 32,
          color: 'rgba(255, 255, 255, 0.8)',
          opacity: subtitleOpacity,
          backdropFilter: 'blur(10px)',
        }}
      >
        Hỗ trợ Telex & VNI
      </div>
    </div>
  );
};
