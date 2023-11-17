//
//  ContentView.swift
//  MetalSwiftUI
//
//  Created by Ryan Token on 11/17/23.
//

import SwiftUI

struct ContentView: View {
    @State private var start = Date.now
    @State private var touch = CGPoint.zero
    
    var body: some View {
        ScrollView {
            VStack {
                // this redraws 120 times per second? Due to the 120hz screen on pro iPhones
                TimelineView(.animation) { tl in
                    let timeElapsed = start.distance(to: tl.date)
                    
                    Image(systemName: "figure.walk.circle")
                        .font(.system(size: 300))
                        .foregroundStyle(.blue)
                    
                        // .colorEffect = take this pixel in, recolor it somehow
                        // repeat for every pixel in parallel
                         .colorEffect(
                            ShaderLibrary.rainbow(.float(timeElapsed))
                         )
                    
                    Image(systemName: "figure.walk.circle")
                        .padding(.vertical)
                        .background(.white)
                        .drawingGroup()
                        .font(.system(size: 300))
                        .foregroundStyle(.blue)
                    
                        .distortionEffect(
                            ShaderLibrary.wave(
                                .float(timeElapsed)
                            ),
                            maxSampleOffset: .zero
                        )
                }
                
                Image("Doggo")
                    .visualEffect { content, proxy in
                        content
                            .layerEffect(ShaderLibrary.loupe(
                                .float2(proxy.size),
                                .float2(touch)
                            ), maxSampleOffset: .zero)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { touch = $0.location }
                    )
                
                TimelineView(.animation) { tl in
                    let timeElapsed = start.distance(to: tl.date)
                    
                    Rectangle()
                        .frame(width: 300, height: 300)
                        .visualEffect { content, proxy in
                            content
                                .colorEffect(
                                    ShaderLibrary.sinebow(
                                        .float2(proxy.size),
                                        .float(timeElapsed)
                                    )
                                )
                        }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
