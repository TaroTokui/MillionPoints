﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;

public class MillionPoints : MonoBehaviour {

    // ==============================
    #region // Defines
        
    const int ThreadBlockSize = 256;

    struct ParticleData
    {
        public Vector3 BasePosition;
        public Vector3 Position;
        public Vector3 Albedo;
        public float rotationSpeed;
    }

    #endregion // Defines

    // --------------------------------------------------
    #region // Serialize Fields

    [SerializeField]
    int _particleCount = 1000000;

    [SerializeField]
    [Range(-Mathf.PI, Mathf.PI)]
    float _phi = Mathf.PI;

    [SerializeField]
    ComputeShader _ComputeShader;
    
    [SerializeField]
    Material _material;

    [SerializeField]
    Vector3 _MeshScale = new Vector3(1f, 1f, 1f);

    /// 表示領域の中心座標
    [SerializeField]
    Vector3 _BoundCenter = Vector3.zero;
    
    /// 表示領域のサイズ
    [SerializeField]
    Vector3 _BoundSize = new Vector3(300f, 300f, 300f);

    #endregion // Serialize Fields

    // --------------------------------------------------
    #region // Private Fields

    ComputeBuffer _ParticleDataBuffer;
    
    /// GPU Instancingの為の引数
    uint[] _GPUInstancingArgs = new uint[5] { 0, 0, 0, 0, 0 };
    
    /// GPU Instancingの為の引数バッファ
    ComputeBuffer _GPUInstancingArgsBuffer;

    // point for particle
    Mesh _pointMesh;

    #endregion // Private Fields

    // --------------------------------------------------
    #region // MonoBehaviour Methods

    void Awake()
    {
        Application.targetFrameRate = 90;
        QualitySettings.vSyncCount = 0;
    }

    void Start()
    {
        // バッファ生成
        this._ParticleDataBuffer = new ComputeBuffer(this._particleCount, Marshal.SizeOf(typeof(ParticleData)));
        this._GPUInstancingArgsBuffer = new ComputeBuffer(1, this._GPUInstancingArgs.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        var particleDataArr = new ParticleData[this._particleCount];
        
        // set default position
        for (int i = 0; i < _particleCount; i++)
        {
            particleDataArr[i].BasePosition = new Vector3(Random.Range(-10.0f, 10.0f), Random.Range(-10.0f, 10.0f), Random.Range(-10.0f, 10.0f));
            particleDataArr[i].Albedo = new Vector3(Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f));
            particleDataArr[i].rotationSpeed = Random.Range(1.0f, 100.0f);
        }
        this._ParticleDataBuffer.SetData(particleDataArr);
        particleDataArr = null;
        
        // creat point mesh
        _pointMesh = new Mesh();
        _pointMesh.vertices = new Vector3[] {
            new Vector3 (0, 0),
        };
        _pointMesh.normals = new Vector3[] {
            new Vector3 (0, 1, 0),
        };
        _pointMesh.SetIndices(new int[] { 0 }, MeshTopology.Points, 0);
    }

    void Update()
    {
        // ComputeShader
        int kernelId = this._ComputeShader.FindKernel("MainCS");
        this._ComputeShader.SetFloat("_time", Time.time / 5.0f);
        this._ComputeShader.SetBuffer(kernelId, "_ParticleDataBuffer", this._ParticleDataBuffer);
        this._ComputeShader.Dispatch(kernelId, (Mathf.CeilToInt(this._particleCount / ThreadBlockSize) + 1), 1, 1);
        
        // GPU Instaicing
        this._GPUInstancingArgs[0] = (this._pointMesh != null) ? this._pointMesh.GetIndexCount(0) : 0;
        this._GPUInstancingArgs[1] = (uint)this._particleCount;
        this._GPUInstancingArgsBuffer.SetData(this._GPUInstancingArgs);
        this._material.SetBuffer("_ParticleDataBuffer", this._ParticleDataBuffer);
        this._material.SetVector("_MeshScale", this._MeshScale);
        Graphics.DrawMeshInstancedIndirect(this._pointMesh, 0, this._material, new Bounds(this._BoundCenter, this._BoundSize), this._GPUInstancingArgsBuffer);
    }

    void OnDestroy()
    {
        if (this._ParticleDataBuffer != null)
        {
            this._ParticleDataBuffer.Release();
            this._ParticleDataBuffer = null;
        }
        if (this._GPUInstancingArgsBuffer != null)
        {
            this._GPUInstancingArgsBuffer.Release();
            this._GPUInstancingArgsBuffer = null;
        }
    }
    
    #endregion // MonoBehaviour Method
}
