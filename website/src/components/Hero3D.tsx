import { useRef } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Sphere, MeshDistortMaterial, Environment } from '@react-three/drei'
import { motion } from 'framer-motion'
import * as THREE from 'three'

function AnimatedJoint({ position, color, speed }: { position: [number, number, number], color: string, speed: number }) {
    const mesh = useRef<THREE.Mesh>(null!)

    useFrame((state) => {
        mesh.current.position.y = position[1] + Math.sin(state.clock.elapsedTime * speed) * 0.2
        mesh.current.rotation.x = state.clock.elapsedTime * 0.5
        mesh.current.rotation.y = state.clock.elapsedTime * 0.2
    })

    return (
        <Sphere args={[0.4, 32, 32]} position={position} ref={mesh}>
            <MeshDistortMaterial
                color={color}
                speed={2}
                distort={0.4}
                roughness={0.2}
                metalness={0.8}
            />
        </Sphere>
    )
}

function Scene() {
    return (
        <group position={[2, 0, 0]}>
            <AnimatedJoint position={[0, 1.5, 0]} color="#0066CC" speed={1.2} />
            <AnimatedJoint position={[-1, 0, 0]} color="#00A3E0" speed={1.5} />
            <AnimatedJoint position={[1, 0, 0]} color="#00A3E0" speed={1.5} />
            <AnimatedJoint position={[0, -1.5, 0]} color="#0066CC" speed={1.2} />

            {/* Connections would ideally be dynamic, simplified here for abstract look */}
            <Environment preset="city" />
        </group>
    )
}

export default function Hero3D() {
    return (
        <section className="relative h-screen w-full flex items-center bg-gradient-to-br from-slate-50 to-slate-200 overflow-hidden">

            {/* 3D Background */}
            <div className="absolute inset-0 z-0">
                <Canvas camera={{ position: [0, 0, 5], fov: 45 }}>
                    <ambientLight intensity={0.5} />
                    <Scene />
                </Canvas>
            </div>

            {/* Content Overlay */}
            <div className="container mx-auto px-6 relative z-10 w-full">
                <div className="max-w-2xl">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.8 }}
                    >
                        <span className="inline-block py-1 px-3 rounded-full bg-blue-100 text-blue-800 text-sm font-semibold mb-6">
                            v1.0 Now Available
                        </span>
                        <h1 className="text-6xl font-bold tracking-tight text-slate-900 mb-6 leading-tight">
                            The Future of <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-600 to-cyan-500">Biomechanics</span> Analysis.
                        </h1>
                        <p className="text-xl text-slate-600 mb-8 leading-relaxed">
                            Native macOS performance. Medical-grade precision.
                            Visualize, compare, and analyze motion data like never before.
                        </p>

                        <div className="flex gap-4">
                            <a href="https://github.com/contact-ajmal/BioMotionPro/releases/download/v1.0/BioMotionPro.dmg"
                                className="px-8 py-4 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-semibold shadow-lg shadow-blue-500/30 transition-all hover:scale-105 flex items-center gap-2">
                                Download for Mac
                            </a>
                            <a href="#features"
                                className="px-8 py-4 bg-white hover:bg-slate-50 text-slate-900 border border-slate-200 rounded-xl font-semibold transition-all hover:scale-105">
                                Explore Features
                            </a>
                        </div>
                    </motion.div>
                </div>
            </div>
        </section>
    )
}
