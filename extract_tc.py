import json
with open(r'C:\Users\Hp\.gemini\antigravity\brain\ff3102a7-c245-466c-9fd4-64528e481635\.system_generated\logs\transcript_full.jsonl', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in reversed(lines):
    data = json.loads(line)
    if 'tool_calls' in data and data['tool_calls']:
        for tc in data['tool_calls']:
            if tc['name'] == 'default_api:replace_file_content' or tc['name'] == 'default_api:write_to_file':
                args = tc['arguments']
                if 'CodeContent' in args:
                    print("Found write_to_file")
                elif 'ReplacementContent' in args:
                    print("Found replace_file_content")
                    # just save it to see what it is
                    with open('subagent_rewrite.txt', 'w', encoding='utf-8') as out:
                        out.write(args['ReplacementContent'])
                    print("Saved ReplacementContent to subagent_rewrite.txt")
                    exit(0)
