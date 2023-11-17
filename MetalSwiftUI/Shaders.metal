//
//  Shaders.metal
//  MetalSwiftUI
//
//  Created by Ryan Token on 11/17/23.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: The Holy Trinity of Metal

// 1. colorEffect() -- return a half4 color given a position, a color, and other args
// 2. distortionEffect() -- return a float2 position given a position and other args
// 3. layerEffect() -- return a half4 color given a position, a SwiftUI Layer, and other args


// MARK: Simple Shaders

// passthrough -- just take in a color and return the same color
// half4 is the return type; half is similar to Int, Double, etc
// the 4 in half4 = the 4 qualities of a color: r, g, b, and a
[[ stitchable ]] half4 passthrough(float2 position, half4 color) {
    return color;
}

// recolor -- return a red color with the same alpha as the original color
[[ stitchable ]] half4 recolor(float2 position, half4 color) {
    return half4(1, 0, 0, color.a);
}

// invertAlpha -- flip the alpha
// things that were transparent are now opaque
// things that were opaque are not transparent
[[ stitchable ]] half4 invertAlpha(float2 position, half4 color) {
    return half4(1, 0, 0, 1 - color.a);
}

// gradient -- for every pixel, generate a new color based on position
[[ stitchable ]] half4 gradient(float2 position, half4 color) {
    return half4(
        position.x / position.y, // r
        0, // g
        position.y / position.x, // b
        color.a // a
    );
}


// MARK: Getting More Advanced with animated colors and distortion effects

// animated rainbow
[[ stitchable ]] half4 rainbow(float2 position, half4 color, float time) {
    float angle = atan2(position.y, position.x) + time;
    return half4(
        sin(angle),
        sin(angle + 2),
        sin(angle + 4),
        color.a
    );
}

// wave
[[ stitchable ]] float2 wave(float2 position, float time) {
    position.y += sin(time * 5 + position.y / 20) * 5;
    return position;
}

// relative wave -- the further we are away from the edge; apply more movement
[[ stitchable ]] float2 relativeWave(float2 position, float time, float2 size) {
    float2 distance = position / size;
    position.y += sin(time * 5 + position.y / 20) * distance.x * 10;
    return position;
}

// MARK: Using SwiftUI Layers in our shaders. Also: Transitions

// loupe -- as the user drags their finger around the SwiftUI layer, zoom where they are
[[ stitchable ]] half4 loupe(float2 position, SwiftUI::Layer layer, float2 size, float2 touch) {
    float maxDistance = 0.05;
    
    float2 uv = position / size;
    float2 center = touch / size;
    float2 delta = uv - center;
    float aspectRatio  = size.x / size.y;
    
    float distance = (delta.x * delta.x) + (delta.y * delta.y) / aspectRatio; // pythagorean theorem
    float totalZoom = 1;
    
    if (distance < maxDistance) {
        totalZoom /= 2;
        totalZoom += distance * 10;
    }
    
    float2 newPosition = delta * totalZoom + center;
    return layer.sample(newPosition * size);
}

// shape transition -- bunch of circles zooming up and make our image fade out
[[ stitchable ]] half4 circles(float2 position, half4 color, float2 size, float amount) {
    float2 uv = position / size;
    float strength = 20; // circle size of 20
    float2 f = fract(position / strength);
    float d = abs(f.x - 0.5) + abs(f.y - 0.5); // "manhattan" distance
    
    if (d + uv.x + uv.y < amount * 3) {
        return color;
    } else {
        return 0;
    }
}

// crosswarp -- stretch pixels out from the center while also making them fade out
[[ stitchable ]] half4 crosswarp(float2 position, SwiftUI::Layer layer, float2 size, float amount) {
    float2 uv = position / size;
    float x = smoothstep(0, 1, amount * 2 + uv.x - 1);
    float2 newMix = mix(uv, float2(0.5), x);
    return mix(layer.sample(newMix * size), 0, x);
}


// MARK: Metal Everything!
/// A shader that generates multiple twisting and turning lines that cycle through colors.
///
/// This shader calculates how far each pixel is from one of 10 lines.
/// Each line has its own undulating color and position based on various
/// sine waves, so the pixel's color is calculating by starting from black
/// and adding in a little of each line's color based on its distance.
///
/// - Parameter position: The user-space coordinate of the current pixel.
/// - Parameter color: The current color of the pixel.
/// - Parameter size: The size of the whole image, in user-space.
/// - Parameter time: The number of elapsed seconds since the shader was created
/// - Returns: The new pixel color.
[[ stitchable ]] half4 sinebow(float2 position, half4 color, float2 size, float time) {
    // Calculate our aspect ratio.
    float aspectRatio = size.x / size.y;
    
    // Calculate our coordinate in UV space, -1 to 1.
    float2 uv = (position / size.x) * 2 - 1;
    
    // Make sure we can create the effect roughly equally no
    // matter what aspect ratio we're in.
    uv.x /= aspectRatio;
    
    // Calculate the overall wave movement.
    float wave = sin(uv.x + time);
    
    // Square that movement, and multiply by a large number
    // to make the peaks and troughs be nice and big.
    wave *= wave * 50;
    
    // Assume a black color by default.
    half3 waveColor = half3(0);
    
    // Create 10 lines in total.
    for (float i = 0; i < 10; i++) {
        // The base brightness of this pixel is 1%, but we
        // need to factor in the position after our wave
        // calculation is taken into account. The abs()
        // call ensures negative numbers become positive,
        // so we care about the absolute distance to the
        // nearest line, rather than ignoring values that
        // are negative.
        float luma = abs(1 / (100 * uv.y + wave));
        
        // This calculates a second sine wave that's unique
        // to each line, so we get waves inside waves.
        float y = sin(uv.x * sin(time) + i * 0.2 + time);
        
        // This offsets each line by that second wave amount,
        // so the waves move non-uniformly.
        uv.y += 0.05 * y;
        
        // Our final color is based on fixed red and blue
        // values, but green fluctuates much more so that
        // the overall brightness varies more randomly.
        // The * 0.5 + 0.5 part ensures the sin() values
        // are between 0 and 1 rather than -1 and 1.
        half3 rainbow = half3(
                              sin(i * 0.3 + time) * 0.5 + 0.5,
                              sin(i * 0.3 + 2 + sin(time * 0.3) * 2) * 0.5 + 0.5,
                              sin(i * 0.3 + 4) * 0.5 + 0.5
                              );
        
        // Add that to the current wave color, ensuring that
        // pixels receive some brightness from all lines.
        waveColor += rainbow * luma;
    }
    
    // Send back the finished color, taking into account the
    // current alpha value.
    return half4(waveColor, color.a) * color.a;
}
