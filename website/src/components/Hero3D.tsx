import { useRef } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Sphere, Environment } from '@react-three/drei'
import * as THREE from 'three'

// Clinical Gait Analysis Visual
// "Stick Figure" Style with GRF Vectors and Joint Angles

const JOINTS_BASE = {
    head: [0, 1.75, 0],
    neck: [0, 1.5, 0],
    shoulderL: [-0.35, 1.45, 0],
    shoulderR: [0.35, 1.45, 0],
    spine: [0, 1.1, 0],
    hipL: [-0.25, 0.9, 0],
    hipR: [0.25, 0.9, 0],
}

function MocapSkeleton() {
    const group = useRef<THREE.Group>(null!)
    const jointsRef = useRef<{ [key: string]: THREE.Mesh }>({})
    const bonesRef = useRef<THREE.Mesh[]>([])

    // Analysis Visuals Refs (Simplified)

    useFrame((state) => {
        const t = state.clock.elapsedTime * 3 // Walking speed

        // Stable "Walking" Motion (Less float, more ground contact)
        const verticalBounce = Math.abs(Math.sin(t)) * 0.05
        group.current.position.y = -0.85 + verticalBounce
        group.current.rotation.y = Math.sin(state.clock.elapsedTime * 0.1) * 0.2 // Slow inspection rotate

        // --- Kinematics (Gait Cycle Approximation) ---
        const hipAngleL = Math.sin(t) * 0.5
        const hipAngleR = Math.sin(t + Math.PI) * 0.5

        // Knee flexion (peaks during swing)
        const kneeAngleL = hipAngleL > 0 ? hipAngleL * 0.8 : 0.1
        const kneeAngleR = hipAngleR > 0 ? hipAngleR * 0.8 : 0.1

        const shoulderAngleL = -hipAngleL * 0.4
        const shoulderAngleR = -hipAngleR * 0.4
        const elbowAngleL = 0.5 + Math.sin(t) * 0.1
        const elbowAngleR = 0.5 + Math.sin(t + Math.PI) * 0.1

        // --- Joint Calculation ---
        const hips = JOINTS_BASE

        // Legs
        const kneeL_Pos = [hips.hipL[0], hips.hipL[1] - 0.45 * Math.cos(hipAngleL), 0.45 * Math.sin(hipAngleL)]
        const kneeR_Pos = [hips.hipR[0], hips.hipR[1] - 0.45 * Math.cos(hipAngleR), 0.45 * Math.sin(hipAngleR)]

        const footL_Pos = [kneeL_Pos[0], kneeL_Pos[1] - 0.45 * Math.cos(hipAngleL - kneeAngleL), kneeL_Pos[2] + 0.45 * Math.sin(hipAngleL - kneeAngleL)]
        const footR_Pos = [kneeR_Pos[0], kneeR_Pos[1] - 0.45 * Math.cos(hipAngleR - kneeAngleR), kneeR_Pos[2] + 0.45 * Math.sin(hipAngleR - kneeAngleR)]

        // Arms
        const elbowL_Pos = [hips.shoulderL[0] - 0.1, hips.shoulderL[1] - 0.3 * Math.cos(shoulderAngleL), 0.3 * Math.sin(shoulderAngleL)]
        const elbowR_Pos = [hips.shoulderR[0] + 0.1, hips.shoulderR[1] - 0.3 * Math.cos(shoulderAngleR), 0.3 * Math.sin(shoulderAngleR)]

        const handL_Pos = [elbowL_Pos[0], elbowL_Pos[1] - 0.25 * Math.cos(shoulderAngleL + elbowAngleL), elbowL_Pos[2] + 0.25 * Math.sin(shoulderAngleL + elbowAngleL)]
        const handR_Pos = [elbowR_Pos[0], elbowR_Pos[1] - 0.25 * Math.cos(shoulderAngleR + elbowAngleR), elbowR_Pos[2] + 0.25 * Math.sin(shoulderAngleR + elbowAngleR)]

        // --- GRF Arrows (Ground Reaction Force) ---
        // Show arrow when foot is on ground (approx by low height)
        /* 
           Note: ArrowHelper is not a React component in R3F by default in the same way, 
           but we can use <arrowHelper /> or a primitive. 
           Actually, standard THREE.ArrowHelper is best wrapped or manipulated.
           Here we will use a simple Cylinder+Cone primitive group for "Vectors" to be fully reactive.
        */

        // --- Update Position Function ---
        const updateJoint = (name: string, pos: number[]) => {
            if (jointsRef.current[name]) {
                jointsRef.current[name].position.set(pos[0], pos[1], pos[2])
            }
        }

        updateJoint('head', hips.head)
        updateJoint('neck', hips.neck)
        updateJoint('shoulderL', hips.shoulderL)
        updateJoint('shoulderR', hips.shoulderR)
        updateJoint('spine', hips.spine)
        updateJoint('hipL', hips.hipL)
        updateJoint('hipR', hips.hipR)
        updateJoint('kneeL', kneeL_Pos)
        updateJoint('kneeR', kneeR_Pos)
        updateJoint('footL', footL_Pos)
        updateJoint('footR', footR_Pos)
        updateJoint('elbowL', elbowL_Pos)
        updateJoint('elbowR', elbowR_Pos)
        updateJoint('handL', handL_Pos)
        updateJoint('handR', handR_Pos)

        // Bones
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
                bone.rotateX(Math.PI / 2)
                bone.scale.set(1, dist, 1)
            }
        })
    })

    // Topology
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
            {/* Markers/Joints - Small, Precise Silver/White */}
            {jointKeys.map((name) => (
                <Sphere
                    key={name}
                    ref={(el) => { if (el) jointsRef.current[name] = el }}
                    args={[0.035, 16, 16]}
                >
                    <meshStandardMaterial color={name.includes('knee') ? "#FF3333" : "#E0E0E0"} roughness={0.5} metalness={0.5} />
                </Sphere>
            ))}

            {/* Segments/Bones - Thin Lines (Cylinders) */}
            {connections.map(([start, end], i) => (
                <mesh
                    key={i}
                    ref={(el) => { if (el) bonesRef.current[i] = el }}
                    userData={{ start, end }}
                >
                    <cylinderGeometry args={[0.015, 0.015, 1, 8]} />
                    <meshStandardMaterial color="#444444" roughness={0.8} />
                </mesh>
            ))}

            {/* Knee Angle Arcs (Visualization of Analysis) */}
            {/* Simplified: A visual disc slice at the knee */}
            {/* Not fully implemented to save complexity, using colored joints instead */}
        </group>
    )
}

function AnalysisFloor() {
    return (
        <group position={[0, -0.85, 0]}>
            <gridHelper args={[10, 10, 0xcccccc, 0xf0f0f0]} />
            {/* Force Plates */}
            <mesh position={[-0.25, 0.01, 0.5]} rotation={[-Math.PI / 2, 0, 0]}>
                <planeGeometry args={[0.4, 0.6]} />
                <meshBasicMaterial color="#E3F2FD" transparent opacity={0.5} side={THREE.DoubleSide} />
                <lineSegments>
                    <edgesGeometry args={[new THREE.PlaneGeometry(0.4, 0.6)]} />
                    <lineBasicMaterial color="#2196F3" />
                </lineSegments>
            </mesh>
            <mesh position={[0.25, 0.01, -0.5]} rotation={[-Math.PI / 2, 0, 0]}>
                <planeGeometry args={[0.4, 0.6]} />
                <meshBasicMaterial color="#E3F2FD" transparent opacity={0.5} side={THREE.DoubleSide} />
                <lineSegments>
                    <edgesGeometry args={[new THREE.PlaneGeometry(0.4, 0.6)]} />
                    <lineBasicMaterial color="#2196F3" />
                </lineSegments>
            </mesh>
        </group>
    )
}

function Scene() {
    return (
        <group position={[3, -0.5, 0]}>
            <MocapSkeleton />
            <Environment preset="studio" />
            <AnalysisFloor />
            <directionalLight position={[-2, 5, 2]} intensity={1.5} />
            <ambientLight intensity={0.5} />
        </group>
    )
}

export default function Hero3D() {
    return (
        <div className="absolute inset-0">
            <Canvas camera={{ position: [0, 1, 6], fov: 40 }}>
                <ambientLight intensity={0.5} />
                <Scene />
            </Canvas>
        </div>
    )
}

