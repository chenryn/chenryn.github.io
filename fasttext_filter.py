#!python3
# -*- coding: utf-8 -*-
from huggingface_hub import hf_hub_download
import fasttext
import os
import yaml
import re
import argparse

def get_model_score(text):
    # 下载模型
    model_path = hf_hub_download(
        repo_id="mlfoundations/fasttext-oh-eli5",
        filename="openhermes_reddit_eli5_vs_rw_v2_bigram_200k_train.bin"
    )

    # 加载模型
    model = fasttext.load_model(model_path)

    # 预处理文本：移除多余空白并合并成单行
    text = ' '.join(text.strip().splitlines())

    # 预测
    predictions = model.predict(text, k=2)
    labels = predictions[0]
    probabilities = predictions[1]

    # 获取预测标签和概率
    pred_label = labels[0]
    pred_prob = probabilities[0]

    # 如果预测为 cc (低质量)，则概率需要反转
    if pred_label == '__label__cc':
        pred_prob = 1 - pred_prob

    return pred_label, pred_prob

def read_markdown_content(file_path):
    """读取 markdown 文件的标题和内容"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 分离 YAML front matter 和正文内容
        if content.startswith('---'):
            parts = content.split('---', 2)
            if len(parts) >= 3:
                try:
                    front_matter = yaml.safe_load(parts[1])
                    title = front_matter.get('title', '')
                    body = parts[2].strip()
                    return title, body
                except yaml.YAMLError:
                    return '', content
        return '', content
    except UnicodeDecodeError:
        # 如果 UTF-8 解码失败，尝试使用 GB2312
        with open(file_path, 'r', encoding='gb2312') as f:
            content = f.read()
            
        if content.startswith('---'):
            parts = content.split('---', 2)
            if len(parts) >= 3:
                try:
                    front_matter = yaml.safe_load(parts[1])
                    title = front_matter.get('title', '')
                    body = parts[2].strip()
                    return title, body
                except yaml.YAMLError:
                    return '', content
        return '', content
    
def process_posts(threshold=0.018112, specific_post=None):  # 添加specific_post参数
    posts_dir = '/Users/rizhiyi/Downloads/gitdir/chenryn-blog.github.com/_posts'
    results = []
    
    # 如果指定了特定文章
    if specific_post:
        # 检查是否提供了完整路径
        if os.path.isfile(specific_post):
            file_path = specific_post
        else:
            # 尝试在_posts目录下查找
            if not specific_post.startswith('_posts/'):
                file_path = os.path.join(posts_dir, specific_post)
            else:
                file_path = os.path.join('/Users/rizhiyi/Downloads/gitdir/chenryn-blog.github.com', specific_post)
        
        if os.path.isfile(file_path) and (file_path.endswith('.markdown') or file_path.endswith('.md')):
            title, content = read_markdown_content(file_path)
            label, score = get_model_score(content)
            
            results.append({
                'title': title,
                'file': os.path.relpath(file_path, '/Users/rizhiyi/Downloads/gitdir/chenryn-blog.github.com/_posts'),
                'label': label,
                'score': score,
                'passed_threshold': score >= threshold
            })
        else:
            print(f"错误：找不到指定的文章 '{specific_post}'")
            return []
    else:
        # 处理所有文章
        for year in os.listdir(posts_dir):
            year_dir = os.path.join(posts_dir, year)
            if not os.path.isdir(year_dir):
                continue
                
            # 遍历该年份下的所有文章
            for post in os.listdir(year_dir):
                if not post.endswith('.markdown') and not post.endswith('.md'):
                    continue
                    
                file_path = os.path.join(year_dir, post)
                title, content = read_markdown_content(file_path)
                
                # 获取文章评分和标签
                label, score = get_model_score(content)
                
                results.append({
                    'title': title,
                    'file': f"{year}/{post}",
                    'label': label,
                    'score': score,
                    'passed_threshold': score >= threshold
                })
    
    # 按评分排序
    results.sort(key=lambda x: x['score'], reverse=True)
    return results

def main():
    # 创建命令行参数解析器
    parser = argparse.ArgumentParser(description='评估博客文章质量')
    parser.add_argument('-p', '--post', help='指定要评估的特定文章路径（相对于_posts目录或绝对路径）')
    parser.add_argument('-t', '--threshold', type=float, default=0.018112, 
                        help='质量评分阈值（默认：0.018112）')
    args = parser.parse_args()
    
    # 处理文章
    results = process_posts(threshold=args.threshold, specific_post=args.post)
    
    if not results:
        return
    
    # 统计信息
    total_posts = len(results)
    passed_posts = sum(1 for r in results if r['passed_threshold'])
    
    print("\n文章质量评分结果：")
    print(f"总文章数: {total_posts}")
    print(f"通过质量阈值的文章数: {passed_posts}")
    print(f"通过率: {(passed_posts/total_posts*100):.2f}%")
    print("-" * 60)
    
    for article in results:
        print(f"标题: {article['title']}")
        print(f"文件: {article['file']}")
        print(f"标签: {article['label']}")
        print(f"评分: {article['score']:.3f}")
        print(f"是否通过阈值: {'是' if article['passed_threshold'] else '否'}")
        print("-" * 60)

if __name__ == '__main__':
    main()