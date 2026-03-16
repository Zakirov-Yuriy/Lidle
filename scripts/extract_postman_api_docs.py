#!/usr/bin/env python3
"""
Извлечение документации API из Postman коллекции
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Any

def load_collection(json_path: str) -> Dict:
    """Загрузить коллекцию из JSON файла."""
    with open(json_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def extract_endpoints(item_list: List[Dict], folder_name: str = "") -> List[Dict]:
    """Рекурсивно извлечь все endpoints из коллекции."""
    endpoints = []
    
    for item in item_list:
        if isinstance(item.get('item'), list):
            # Это папка
            folder = item.get('name', 'Unknown')
            endpoints.extend(extract_endpoints(item['item'], folder))
        else:
            # Это endpoint
            endpoint = {
                'folder': folder_name,
                'name': item.get('name', ''),
                'method': item.get('request', {}).get('method', 'GET'),
                'url': item.get('request', {}).get('url', ''),
                'description': item.get('request', {}).get('description', ''),
                'headers': item.get('request', {}).get('header', []),
                'body': item.get('request', {}).get('body', {}),
                'response': item.get('response', [])
            }
            endpoints.append(endpoint)
    
    return endpoints

def generate_markdown(endpoints: List[Dict], collection_info: Dict) -> str:
    """Генерировать Markdown документацию из endpoints."""
    
    md = "# API Документация\n\n"
    
    # Добавить описание из коллекции
    if collection_info.get('description'):
        md += f"{collection_info['description']}\n\n"
    
    # Сгруппировать endpoints по папкам
    folders = {}
    for endpoint in endpoints:
        folder = endpoint['folder'] or 'Без категории'
        if folder not in folders:
            folders[folder] = []
        folders[folder].append(endpoint)
    
    # Логировать информацию
    print(f"✅ Найдено {len(endpoints)} endpoints в {len(folders)} категориях")
    for folder, eps in folders.items():
        print(f"  - {folder}: {len(eps)} endpoints")
    
    # Генерировать документацию для каждой папки
    for folder, eps in sorted(folders.items()):
        md += f"## {folder}\n\n"
        
        for endpoint in eps:
            method = endpoint['method']
            name = endpoint['name']
            md += f"### {method} - {name}\n\n"
            
            if endpoint['description']:
                md += f"**Описание:** {endpoint['description']}\n\n"
            
            # URL
            url = endpoint['url']
            if isinstance(url, dict):
                if 'raw' in url:
                    md += f"**URL:** `{url['raw']}`\n\n"
            else:
                md += f"**URL:** `{url}`\n\n"
            
            # Заголовки
            if endpoint['headers']:
                md += "**Заголовки:**\n```\n"
                for header in endpoint['headers']:
                    key = header.get('key', '')
                    value = header.get('value', '')
                    md += f"{key}: {value}\n"
                md += "```\n\n"
            
            # Body
            if endpoint['body'] and endpoint['body'].get('raw'):
                md += "**Body:**\n```json\n"
                try:
                    body_json = json.loads(endpoint['body']['raw'])
                    md += json.dumps(body_json, ensure_ascii=False, indent=2)
                except:
                    md += endpoint['body']['raw']
                md += "\n```\n\n"
            
            # Response примеры
            if endpoint['response']:
                md += f"**Response примеры:**\n"
                for resp in endpoint['response'][:2]:  # Только первые 2
                    md += f"- {resp.get('name', 'Response')}\n"
                md += "\n"
            
            md += "---\n\n"
    
    return md

def main():
    json_path = 'c:\\Users\\zakco\\AppData\\Roaming\\Code\\User\\workspaceStorage\\4fa44ed50f2bfa307c97c2f9200cb1f5\\GitHub.copilot-chat\\chat-session-resources\\0751b946-b50f-4c41-b7d4-6dd3f11bf289\\toolu_bdrk_011MtCxUTuk92XRd3MUSRyLa__vscode-1773644403117\\content.json'
    
    print("📥 Загружаю коллекцию...")
    collection_data = load_collection(json_path)
    collection = collection_data.get('collection', {})
    
    print("🔍 Анализирую endpoints...")
    info = collection.get('info', {})
    items = collection.get('item', [])
    
    # Извлечь endpoints
    endpoints = extract_endpoints(items)
    
    # Генерировать документацию
    print("📝 Генерирую документацию...")
    markdown = generate_markdown(endpoints, info)
    
    # Сохранить в проект
    docs_dir = Path('docs/api')
    docs_dir.mkdir(parents=True, exist_ok=True)
    
    output_file = docs_dir / 'API_DOCUMENTATION.md'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(markdown)
    
    print(f"✅ Документация сохранена в {output_file}")
    
    # Также сохранить оригинальную коллекцию
    collection_file = docs_dir / 'postman_collection.json'
    with open(collection_file, 'w', encoding='utf-8') as f:
        json.dump(collection_data, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Коллекция сохранена в {collection_file}")

if __name__ == '__main__':
    main()
