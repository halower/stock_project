# -*- coding: utf-8 -*-
"""大语言模型服务模块，用于调用各种 LLM API"""

import os
import json
import requests
from typing import Dict, Any, List, Optional
import time

from app.core.logging import logger
from app.core.config import (
    AI_MAX_TOKENS, AI_TEMPERATURE
)

def get_completion(
    prompt: str, 
    max_tokens: int = 1000, 
    temperature: float = 0.7,
    model: str = None,
    endpoint: str = None,
    api_key: str = None
) -> str:
    """使用默认设置调用LLM获取回复
    
    Args:
        prompt: 提示词
        max_tokens: 最大生成令牌数
        temperature: 温度参数，控制随机性
        model: 可选的模型名称，若未提供则使用默认值
        endpoint: 可选的API端点，若未提供则使用默认值
        api_key: 可选的API密钥，若未提供则使用默认值
        
    Returns:
        LLM生成的回复
    """
    # 使用 get_completion_with_custom_params 实现
    return get_completion_with_custom_params(
        prompt=prompt,
        max_tokens=max_tokens,
        temperature=temperature,
        model=model,
        endpoint=endpoint,
        api_key=api_key
    )

def get_completion_with_custom_params(
    prompt: str,
    model: str = None,
    endpoint: str = None,
    api_key: str = None,
    max_tokens: int = 1000,
    temperature: float = 0.7,
    retry_count: int = 3,
    **kwargs
) -> str:
    """使用自定义参数调用LLM获取回复
    
    Args:
        prompt: 提示词
        model: LLM模型名称
        endpoint: API端点
        api_key: API密钥
        max_tokens: 最大生成令牌数
        temperature: 温度参数，控制随机性
        retry_count: 重试次数
        **kwargs: 其他参数
        
    Returns:
        LLM生成的回复
    """
    # 检查必要参数
    if not model or not endpoint or not api_key:
        logger.error("调用LLM缺少必要参数: model, endpoint, api_key")
        return "无法调用LLM，缺少必要参数。请联系管理员配置模型参数。"
    
    # 构造消息
    messages = [{"role": "user", "content": prompt}]
    
    # 构造请求参数
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature
    }
    
    # 添加其他自定义参数
    for key, value in kwargs.items():
        payload[key] = value
    
    # 设置请求头
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    
    # 发送请求并处理响应
    for attempt in range(retry_count):
        try:
            response = requests.post(
                endpoint,
                headers=headers,
                json=payload,
                timeout=60  # 优化超时时间为60秒，避免长时间阻塞
            )
            
            # 检查响应状态码
            if response.status_code == 200:
                try:
                    response_data = response.json()
                    
                    # 适配不同的API响应格式
                    if "choices" in response_data and len(response_data["choices"]) > 0:
                        # OpenAI 格式
                        if "message" in response_data["choices"][0]:
                            return response_data["choices"][0]["message"].get("content", "")
                        elif "text" in response_data["choices"][0]:
                            return response_data["choices"][0]["text"]
                    
                    # 其他可能的响应格式
                    if "response" in response_data:
                        return response_data["response"]
                    
                    # 如果以上都不匹配，尝试返回整个响应
                    logger.warning(f"无法解析LLM响应格式: {response_data}")
                    return str(response_data)
                    
                except json.JSONDecodeError as e:
                    logger.error(f"解析LLM响应JSON失败: {str(e)}")
                    if attempt < retry_count - 1:
                        time.sleep(1)  # 等待一秒后重试
                        continue
                    return "解析LLM响应失败，请稍后重试。"
            else:
                error_msg = f"LLM API 请求失败，状态码: {response.status_code}"
                try:
                    error_data = response.json()
                    error_msg += f", 错误信息: {error_data}"
                except:
                    error_msg += f", 响应内容: {response.text[:200]}"
                
                logger.error(error_msg)
                
                if attempt < retry_count - 1:
                    time.sleep(1)  # 等待一秒后重试
                    continue
                
                return f"调用LLM服务失败，请稍后重试。错误代码: {response.status_code}"
                
        except requests.RequestException as e:
            logger.error(f"请求LLM API时发生异常: {str(e)}")
            if attempt < retry_count - 1:
                time.sleep(1)  # 等待一秒后重试
                continue
            return "连接LLM服务失败，请检查网络或稍后重试。"
    
    return "多次尝试调用LLM服务均失败，请稍后重试。"

def get_chat_completion(
    messages: List[Dict[str, str]],
    model: str = None,
    endpoint: str = None,
    api_key: str = None,
    max_tokens: int = 1000,
    temperature: float = 0.7,
    **kwargs
) -> str:
    """使用对话格式调用LLM获取回复
    
    Args:
        messages: 对话消息列表，格式为[{"role": "user", "content": "你好"}, ...]
        model: LLM模型名称
        endpoint: API端点
        api_key: API密钥
        max_tokens: 最大生成令牌数
        temperature: 温度参数，控制随机性
        **kwargs: 其他参数
        
    Returns:
        LLM生成的回复
    """
    # 检查必要参数
    if not model or not endpoint or not api_key:
        logger.error("调用LLM缺少必要参数: model, endpoint, api_key")
        return "无法调用LLM，缺少必要参数。请联系管理员配置模型参数。"
    
    # 构造请求参数
    payload = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature
    }
    
    # 添加其他自定义参数
    for key, value in kwargs.items():
        payload[key] = value
    
    # 设置请求头
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    
    # 发送请求并处理响应
    try:
        response = requests.post(
            endpoint,
            headers=headers,
            json=payload,
            timeout=60  # 优化超时时间为60秒
        )
        
        # 检查响应状态码
        if response.status_code == 200:
            try:
                response_data = response.json()
                
                # 适配不同的API响应格式
                if "choices" in response_data and len(response_data["choices"]) > 0:
                    # OpenAI 格式
                    if "message" in response_data["choices"][0]:
                        return response_data["choices"][0]["message"].get("content", "")
                    elif "text" in response_data["choices"][0]:
                        return response_data["choices"][0]["text"]
                
                # 其他可能的响应格式
                if "response" in response_data:
                    return response_data["response"]
                
                # 如果以上都不匹配，尝试返回整个响应
                logger.warning(f"无法解析LLM响应格式: {response_data}")
                return str(response_data)
                
            except json.JSONDecodeError as e:
                logger.error(f"解析LLM响应JSON失败: {str(e)}")
                return "解析LLM响应失败，请稍后重试。"
        else:
            error_msg = f"LLM API 请求失败，状态码: {response.status_code}"
            try:
                error_data = response.json()
                error_msg += f", 错误信息: {error_data}"
            except:
                error_msg += f", 响应内容: {response.text[:200]}"
            
            logger.error(error_msg)
            return f"调用LLM服务失败，请稍后重试。错误代码: {response.status_code}"
            
    except requests.RequestException as e:
        logger.error(f"请求LLM API时发生异常: {str(e)}")
        return "连接LLM服务失败，请检查网络或稍后重试。" 