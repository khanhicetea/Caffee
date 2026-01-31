import React from 'react';
import {useCurrentFrame, interpolate} from 'remotion';

export const FeaturesScene: React.FC = () => {
  const frame = useCurrentFrame();

  // Vietnamese features from web/index.html
  const features = [
    {
      icon: '🇻🇳',
      title: 'Gõ tiếng Việt đúng chuẩn',
      description: 'Đặt dấu theo kiểu cũ - vì tính thẩm mỹ và nhất quán - chữ viết là data vì vậy nó nên nhất quán cách viết',
    },
    {
      icon: '⌨️',
      title: 'Hỗ trợ Telex & VNI',
      description: 'Sửa dấu mà không cần xóa đi gõ lại, hiểu khi bạn cần gõ từ tiếng Anh',
    },
    {
      icon: '🧠',
      title: 'Nhớ chế độ gõ theo ứng dụng',
      description: 'Ví dụ: app A là Việt, switch qua app B trước đó là English, switch lại app A thì chuyển về Việt',
    },
    {
      icon: '🔧',
      title: 'Sửa lỗi thanh địa chỉ & Excel',
      description: 'Lỗi này khá phổ biến trên trình duyệt và Excel, gây ra lỗi gõ rất khó chịu',
    },
  ];

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100%',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        padding: '10px',
      }}
    >
      {/* Title */}
      <h2
        style={{
          fontSize: 100,
          fontWeight: 700,
          color: 'white',
          marginBottom: 50,
          opacity: interpolate(frame, [0, 30], [0, 1], {extrapolateRight: 'clamp'}),
        }}
      >
        Tính năng nổi bật
      </h2>

      {/* Features Grid */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: 40,
          maxWidth: 1800,
          width: '100%',
        }}
      >
        {features.map((feature, index) => {
          const delay = index * 15;
          const opacity = interpolate(frame, [20 + delay, 50 + delay], [0, 1], {
            extrapolateRight: 'clamp',
          });
          const translateY = interpolate(frame, [20 + delay, 50 + delay], [30, 0], {
            extrapolateRight: 'clamp',
          });

          return (
            <div
              key={index}
              style={{
                background: 'rgba(255, 255, 255, 0.1)',
                borderRadius: 24,
                padding: 50,
                backdropFilter: 'blur(10px)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                opacity,
                transform: `translateY(${translateY}px)`,
              }}
            >
              {/* Icon + Title Row */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 20,
                  marginBottom: 24,
                }}
              >
                <div
                  style={{
                    fontSize: 72,
                  }}
                >
                  {feature.icon}
                </div>
                <h3
                  style={{
                    fontSize: 42,
                    fontWeight: 600,
                    color: 'white',
                    margin: 0,
                  }}
                >
                  {feature.title}
                </h3>
              </div>
              <p
                style={{
                  fontSize: 32,
                  color: 'rgba(255, 255, 255, 0.7)',
                  lineHeight: 1.4,
                }}
              >
                {feature.description}
              </p>
            </div>
          );
        })}
      </div>
    </div>
  );
};
