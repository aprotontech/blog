---
title: "Llm Inference"
date: 2025-06-12T20:52:39+08:00
draft: true
---

前置的一些"LLM数字科学":
LLM参数量（不考虑偏置）
    Token Embedding: TokenDictCount*H; H是隐层维度
    Attention(QKV投影矩阵+输出变换: 3*H*H/numHeads*numHeads+H*H=4H*H)
    MLP矩阵,一般中间层是4H: 2*H*4H
    Norm: 2*2*H=4H
    总计： Layer*(H*H*4+2*H*4H+4H)+TokenDictCount*H=12*Layer*H*H
LLM推理需要的计算量
    Token Embedding: 查表，0计算
    Attention(QKV投影): 3*SeqLen*H*H*2=6*SeqLen*H*H; 2是加法+乘法
    Attention(softmax): 
    Attention(QK^T): SeqLen*H/numHeads*SeqLen*numHeads*2=2*SeqLen*SeqLen*H
    Attention(AV): SeqLen*SeqLen*H/numHeads*SeqLen*2=2*SeqLen*SeqLen*H
    Attention(Output): SeqLen*H*H*2=2*SeqLen*H*H
    MLP: 2*SeqLen*H*4H*2=16*SeqLen*H*H
    总计： Layer*(24*SeqLen*H*H+4*SeqLen*SeqLen*H)

大模型推理时，主要面临的挑战：
显存：模型推理占用GPU显存非常高，单GPU显存有限制，如何使用更少的GPU显存运行更多的模型/QUERY
GPU利用率：如何提升GPU利用率
吞吐量/延迟: 如何服务更多的query，如何更快的生成token
更大的模型：如何放更大的模型

结合市面上的一些工程和论文，总结下来大模型优化的几个方向有以下几个方向。这个分化算是我自己的理解，可能不一定准确：
模型自身：如何降低模型自身的参数量和计算量
    量化/稀疏化/MQA/GQA
单卡优化：单卡时如何提升计算速度
    算子融合/多请求并发/PagedAttention/PrefixCache/Cache量化
    投机采样/上下文窗口优化
多卡多机优化：多卡多机时如何提升计算速度
    PD分离/Tensor并行/Pipeline并行/Sequence并行
硬件优化：CPU/NPU等
系统工程：
    Query调度/Semantic Cache