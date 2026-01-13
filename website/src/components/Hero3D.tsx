import { useRef } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Sphere, Environment } from '@react-three/drei'
import { motion } from 'framer-motion'
import * as THREE from 'three'

const JOINTS_BASE = {
    head: [0, 1.7, 0],
    neck: [0, 1.5, 0],
    shoulderL: [-0.35, 1.45, 0],
    shoulderR: [0.35, 1.45, 0],
    spine: [0, 1.1, 0],
    hipL: [-0.25, 0.9, 0],
    hipR: [0.25, 0.9, 0],
}

// Helper to calculate position based on rotation around a parent
// (Unused helper removed)

function MocapSkeleton() {
    const group = useRef<THREE.Group>(null!)

    // Refs for dynamic joints
    const jointsRef = useRef<{ [key: string]: THREE.Mesh }>({})
    const bonesRef = useRef<THREE.Mesh[]>([])

    useFrame((state) => {
        const t = state.clock.elapsedTime * 4 // Run speed

        // Group floating
        group.current.position.y = -0.8 + Math.sin(t * 0.5) * 0.05
        group.current.rotation.y = Math.sin(state.clock.elapsedTime * 0.2) * 0.3

        // Procedural Animation Logic
        // Angles
        const hipAngleL = Math.sin(t) * 0.5
        const hipAngleR = Math.sin(t + Math.PI) * 0.5
        const kneeAngleL = hipAngleL > 0 ? hipAngleL * 0.5 : Math.abs(hipAngleL) * 1.2
        const kneeAngleR = hipAngleR > 0 ? hipAngleR * 0.5 : Math.abs(hipAngleR) * 1.2

        const shoulderAngleL = -hipAngleL * 0.6 // Arms swing opposite to legs
        const shoulderAngleR = -hipAngleR * 0.6
        const elbowAngleL = Math.abs(shoulderAngleL) * 0.8 + 0.5
        const elbowAngleR = Math.abs(shoulderAngleR) * 0.8 + 0.5

        // Base Positions
        const hips = JOINTS_BASE

        // Calculate Limbs
        // Legs (Thigh -> Shin)
        const kneeL_Pos = [hips.hipL[0], hips.hipL[1] - 0.45 * Math.cos(hipAngleL), 0.45 * Math.sin(hipAngleL)]
        const kneeR_Pos = [hips.hipR[0], hips.hipR[1] - 0.45 * Math.cos(hipAngleR), 0.45 * Math.sin(hipAngleR)]

        const footL_Pos = [kneeL_Pos[0], kneeL_Pos[1] - 0.45 * Math.cos(hipAngleL - kneeAngleL), kneeL_Pos[2] + 0.45 * Math.sin(hipAngleL - kneeAngleL)]
        const footR_Pos = [kneeR_Pos[0], kneeR_Pos[1] - 0.45 * Math.cos(hipAngleR - kneeAngleR), kneeR_Pos[2] + 0.45 * Math.sin(hipAngleR - kneeAngleR)]

        // Arms (Upper -> Lower)
        const elbowL_Pos = [hips.shoulderL[0] - 0.1, hips.shoulderL[1] - 0.3 * Math.cos(shoulderAngleL), 0.3 * Math.sin(shoulderAngleL)]
        const elbowR_Pos = [hips.shoulderR[0] + 0.1, hips.shoulderR[1] - 0.3 * Math.cos(shoulderAngleR), 0.3 * Math.sin(shoulderAngleR)]

        const handL_Pos = [elbowL_Pos[0], elbowL_Pos[1] - 0.25 * Math.cos(shoulderAngleL + elbowAngleL), elbowL_Pos[2] + 0.25 * Math.sin(shoulderAngleL + elbowAngleL)]
        const handR_Pos = [elbowR_Pos[0], elbowR_Pos[1] - 0.25 * Math.cos(shoulderAngleR + elbowAngleR), elbowR_Pos[2] + 0.25 * Math.sin(shoulderAngleR + elbowAngleR)]

        // Update Joints Visuals
        const updateJoint = (name: string, pos: number[]) => {
            if (jointsRef.current[name]) {
                jointsRef.current[name].position.set(pos[0], pos[1], pos[2])
            }
        }

        // Static/Base Joints
        updateJoint('head', hips.head)
        updateJoint('neck', hips.neck)
        updateJoint('shoulderL', hips.shoulderL)
        updateJoint('shoulderR', hips.shoulderR)
        updateJoint('spine', hips.spine)
        updateJoint('hipL', hips.hipL)
        updateJoint('hipR', hips.hipR)

        // Dynamic Joints
        updateJoint('kneeL', kneeL_Pos)
        updateJoint('kneeR', kneeR_Pos)
        updateJoint('footL', footL_Pos)
        updateJoint('footR', footR_Pos)
        updateJoint('elbowL', elbowL_Pos)
        updateJoint('elbowR', elbowR_Pos)
        updateJoint('handL', handL_Pos)
        updateJoint('handR', handR_Pos)

        // Bones (Re-calculate cylinder transforms)
        bonesRef.current.forEach((bone) => {
            if (!bone.userData.start || !bone.userData.end) return
            const startMesh = jointsRef.current[bone.userData.start]
            const endMesh = jointsRef.current[bone.userData.end]

            if (startMesh && endMesh) {
                const start = startMesh.position
                const end = endMesh.position
                const dist = start.distanceTo(end)
                const mid = start.clone().add(end).multiplyScalar(0.5)

                bone.position.copy(mid)
                bone.lookAt(end)
                bone.rotateX(Math.PI / 2) // Align cylinder Y axis
                bone.scale.set(1, dist, 1) // Scale Y to distance
            }
        })
    })

    // Define topology
    const jointKeys = ['head', 'neck', 'shoulderL', 'shoulderR', 'spine', 'hipL', 'hipR', 'kneeL', 'kneeR', 'footL', 'footR', 'elbowL', 'elbowR', 'handL', 'handR']

    const connections = [
        ['head', 'neck'], ['neck', 'spine'],
        ['neck', 'shoulderL'], ['neck', 'shoulderR'],
        ['shoulderL', 'elbowL'], ['elbowL', 'handL'],
        ['shoulderR', 'elbowR'], ['elbowR', 'handR'],
        ['spine', 'hipL'], ['spine', 'hipR'],
        ['hipL', 'kneeL'], ['kneeL', 'footL'],
        ['hipR', 'kneeR'], ['kneeR', 'footR']
    ]

    return (
        <group ref={group}>
            {/* Joints */}
            {jointKeys.map((name) => (
                <Sphere
                    key={name}
                    ref={(el) => { if (el) jointsRef.current[name] = el }}
                    args={[0.07, 16, 16]}
                >
                    {/* Glowing Blue Material */}
                    <meshStandardMaterial color="#00A3E0" emissive="#0066CC" emissiveIntensity={1.5} toneMapped={false} />
                </Sphere>
            ))}

            {/* Bones */}
            {connections.map(([start, end], i) => (
                <mesh
                    key={i}
                    ref={(el) => { if (el) bonesRef.current[i] = el }}
                    userData={{ start, end }}
                >
                    <cylinderGeometry args={[0.025, 0.025, 1, 8]} />
                    {/* Glassy Bone Material */}
                    <meshPhysicalMaterial
                        color="#ffffff"
                        transmission={0.6}
                        opacity={0.5}
                        metalness={0.2}
                        roughness={0.1}
                        transparent
                    />
                </mesh>
            ))}
        </group>
    )
}

function GridFlood() {
    // A cool animated grid floor
    const grid = useRef<THREE.GridHelper>(null!)
    useFrame((state) => {
        grid.current.position.z = (state.clock.elapsedTime * 0.5) % 1
    })
    return <gridHelper ref={grid} args={[20, 20, 0x88CCFF, 0xeeeeee]} position={[0, -1.5, 0]} />
}

function Scene() {
    return (
        <group position={[2, 0, 0]}>
            <MocapSkeleton />
            <Environment preset="city" />
            <GridFlood />
            <directionalLight position={[-5, 5, 5]} intensity={1} color="#0066CC" />
            <pointLight position={[2, 2, 2]} intensity={2} color="#00A3E0" />
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
