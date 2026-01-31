import type React from "react";
import { Composition } from "remotion";
import { CaffeePromo } from "./compositions/CaffeePromo";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="CaffeePromo"
        component={CaffeePromo}
        durationInFrames={700}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
