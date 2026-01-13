import { useRef } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Sphere, Environment } from '@react-three/drei'
import { motion } from 'framer-motion'
import * as THREE from 'three'

const JOINTS = {
    head: [0, 1.8, 0],
    neck: [0, 1.5, 0],
    shoulderL: [-0.4, 1.4, 0],
    shoulderR: [0.4, 1.4, 0],
    elbowL: [-0.7, 1.0, 0.2],
    elbowR: [0.7, 1.0, -0.2],
    handL: [-0.9, 0.6, 0.4],
    handR: [0.9, 0.6, -0.4],
    spine: [0, 1.0, 0],
    hipL: [-0.3, 0.8, 0],
    hipR: [0.3, 0.8, 0],
    kneeL: [-0.3, 0.4, 0.3],
    kneeR: [0.3, 0.4, 0.3],
    footL: [-0.3, 0.0, 0],
    footR: [0.3, 0.0, 0],
} as const

const BONES = [
    ['head', 'neck'],
    ['neck', 'spine'],
    ['neck', 'shoulderL'], ['neck', 'shoulderR'],
    ['shoulderL', 'elbowL'], ['elbowL', 'handL'],
    ['shoulderR', 'elbowR'], ['elbowR', 'handR'],
    ['spine', 'hipL'], ['spine', 'hipR'],
    ['hipL', 'kneeL'], ['kneeL', 'footL'],
    ['hipR', 'kneeR'], ['kneeR', 'footR'],
]

function MocapSkeleton() {
    const group = useRef<THREE.Group>(null!)

    useFrame((state) => {
        // Slow rotation to show 3D depth
        group.current.rotation.y = Math.sin(state.clock.elapsedTime * 0.3) * 0.5
        // Floating effect
        group.current.position.y = -0.5 + Math.sin(state.clock.elapsedTime * 0.5) * 0.1
    })

    return (
        <group ref={group}>
            {/* Joints */}
            {Object.entries(JOINTS).map(([name, pos]) => (
                <Sphere key={name} args={[0.08, 16, 16]} position={pos as [number, number, number]}>
                    <meshStandardMaterial color={name.includes('L') ? '#00A3E0' : '#0066CC'} emissive="#002244" emissiveIntensity={0.5} roughness={0.4} />
                </Sphere>
            ))}

            {/* Bones */}
            {BONES.map(([start, end], i) => {
                const startPos = new THREE.Vector3(...JOINTS[start as keyof typeof JOINTS])
                const endPos = new THREE.Vector3(...JOINTS[end as keyof typeof JOINTS])
                const length = startPos.distanceTo(endPos)
                const midPoint = startPos.clone().add(endPos).multiplyScalar(0.5)

                // Calculate rotation to align cylinder with points
                const direction = endPos.clone().sub(startPos).normalize()
                const quaternion = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction)

                return (
                    <mesh key={i} position={midPoint} quaternion={quaternion}>
                        <cylinderGeometry args={[0.02, 0.02, length, 8]} />
                        <meshStandardMaterial color="#AABBDD" transparent opacity={0.6} />
                    </mesh>
                )
            })}
        </group>
    )
}

function Scene() {
    return (
        <group position={[2, 0, 0]}>
            <MocapSkeleton />
            <Environment preset="city" />
            <gridHelper args={[10, 10, 0xdddddd, 0xeeeeee]} position={[0, -0.5, 0]} />
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
