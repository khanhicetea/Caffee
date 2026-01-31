import React from 'react';
import {AbsoluteFill} from 'remotion';
import {TransitionSeries, linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {IntroScene} from '../components/IntroScene';
import {TypingScene} from '../components/TypingScene';
import {FeaturesScene} from '../components/FeaturesScene';
import {OutroScene} from '../components/OutroScene';

export const CaffeePromo: React.FC = () => {
  return (
    <AbsoluteFill
      style={{
        background: 'linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)',
      }}
    >
      <TransitionSeries>
        {/* Scene 1: Intro - 5 seconds */}
        <TransitionSeries.Sequence durationInFrames={150}>
          <IntroScene />
        </TransitionSeries.Sequence>

        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({durationInFrames: 20})}
        />

        {/* Scene 2: Telex Typing Demo - 10 seconds (faster typing, more text) */}
        <TransitionSeries.Sequence durationInFrames={300}>
          <TypingScene />
        </TransitionSeries.Sequence>

        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({durationInFrames: 20})}
        />

        {/* Scene 3: Features - 6 seconds */}
        <TransitionSeries.Sequence durationInFrames={180}>
          <FeaturesScene />
        </TransitionSeries.Sequence>

        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({durationInFrames: 20})}
        />

        {/* Scene 4: Outro - 5 seconds */}
        <TransitionSeries.Sequence durationInFrames={150}>
          <OutroScene />
        </TransitionSeries.Sequence>
      </TransitionSeries>
    </AbsoluteFill>
  );
};
