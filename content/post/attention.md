---
title: "Attention学习"
date: 2024-10-17T21:54:32+08:00
draft: false
categories:
  - LLM
tags:
  - 算法
---
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/katex.min.css" integrity="sha384-DYV02DUBOnbDOvGdyY39hAamjFl8A6L1rWd7Ahpplx6HUs/zyCo/s/5V4AIMpL+S" crossorigin="anonymous">  
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/katex.min.js" integrity="sha384-7A9/Zis/0CJi7SEJYfZoXFN9kPm9LP3tL5UJIsLUIIwAtt6OLH48hx1wYLUH3nC2" crossorigin="anonymous"></script>  
<script defer src="https://cdn.jsdelivr.net/npm/katex@0.13.11/dist/contrib/auto-render.js" integrity="sha384-9CMTKMwS8Jm8aE/uWIk3qffu5r/lUC+qOknBnrPN+N8LPgXWQncc3Ed5G3FsLWzW" crossorigin="anonymous" onload="renderMathInElement(document.body);"></script>

## Attention
Attention计算公式： 

$Attention(Q, K, V) = softmax(\frac{Q*K^T}{\sqrt{d_k}})*V$

Q --> [batch_size, input_length, input_dims]
- batch_size: 批大小
- input_length: `Query`长度（训练时可以取最大长度）
- input_dims: 每个`Token`用一个向量表达，向量的长度


softmax 的计算原理 $softmax([z_1,z_2,...,z_n]) = [ \frac{e^{z_i}}{\sum_{j=1}^{n}e^{z_j}} ]$



问题：
1. input_length选择多大？
2. 超长的query如何处理？
3. input_dims一般是多少？


## Multi-Head Attention
核心原理：
- 将长度为`input_dims`的向量拆分为 `N`个长度为 $\frac{input_dims}{N}$ 的向量，然后并行计算

问题：
1. 这么拆分有什么好处？

## Self Attention
当 $Q = K = V$ 时，即为 Self Attention


## 代码
这一段`Multi-Head Self Attention`代码比较清晰，对attention的理解非常有帮助

<details>
<summary>self_attention.py</summary>

```python
import torch
import torch.nn.functional as F
 
class SelfAttention(torch.nn.Module):
    def __init__(self, input_dim, heads):
        super(SelfAttention, self).__init__()
        self.input_dim = input_dim
        self.heads = heads
        self.head_dim = input_dim // heads
 
        # W_q,W_k,W_v,w_o 都是 input_dim*input_dim 的矩阵
        self.W_q = torch.nn.Linear(input_dim, input_dim)
        self.W_k = torch.nn.Linear(input_dim, input_dim)
        self.W_v = torch.nn.Linear(input_dim, input_dim)
 
        self.W_o = torch.nn.Linear(input_dim, input_dim)
 
    def forward(self, x):
        batch_size = x.shape[0]
 
        # Linear transformation to get Q, K, V
        Q = self.W_q(x)
        K = self.W_k(x)
        V = self.W_v(x)
 
        # Reshape Q, K, V to have multiple heads
        Q = Q.view(batch_size, -1, self.heads, self.head_dim).permute(0, 2, 1, 3)
        K = K.view(batch_size, -1, self.heads, self.head_dim).permute(0, 2, 1, 3)
        V = V.view(batch_size, -1, self.heads, self.head_dim).permute(0, 2, 1, 3)
 
        # Compute attention scores
        scores = torch.matmul(Q, K.permute(0, 1, 3, 2)) / (self.head_dim ** 0.5)
        attention_weights = F.softmax(scores, dim=-1)
 
        # Apply attention weights to V
        attention_output = torch.matmul(attention_weights, V)
 
        # Reshape and concatenate heads
        attention_output = attention_output.permute(0, 2, 1, 3).contiguous()
        attention_output = attention_output.view(batch_size, -1, self.input_dim)
 
        # Final linear transformation
        output = self.W_o(attention_output)
 
        return output
 
# 使用示例
input_dim = 64
seq_length = 10
heads = 8
input_data = torch.randn(1, seq_length, input_dim)  # 生成随机输入数据
self_attention = SelfAttention(input_dim, heads)
output = self_attention(input_data)
print(output.shape)  # 输出形状：torch.Size([1, 10, 64])
```
</details>