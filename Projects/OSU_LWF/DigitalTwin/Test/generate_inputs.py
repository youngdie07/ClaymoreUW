import json
import copy
import os

# 1) 템플릿 로드
script_dir = os.path.dirname(os.path.abspath(__file__))
template_path = os.path.join(script_dir, 'input_template.json')
with open(template_path, 'r') as f:
    template = json.load(f)

# 2) 파라미터 목록 설정 (기본값 예시 포함)
# debris quantity
debris_array_list = [ 
    [1, 1, 5],  # D5
    [2, 1, 5],  # D10
    [4, 1, 5],  # D20
    [6, 1, 5]   # D30   
]
# Forest location
forest_loc_list = [
    60.00, # F5m
    62.50, # F7.5m
    65.00, # F10m
    67.50  # F12.5m
]
# debris geometry (rotation, shape)와 spacing을 연동
# 예시: debris_geo_list와 debris_spacing_list를 zip으로 묶어서 사용
# debris geometry (rotation, shape)
debris_geo_list = [
    [0.3, 0.1, 0.1],   # 0.3box-0deg
    [0.1, 0.1, 0.3],   # 0.3box-90deg
    [0.15, 0.05, 0.05],  # 0.15box-0deg
    [0.05, 0.05, 0.15],  # 0.15box-90deg
    # [0.3, 0.0, 0.025], # log-0deg
    # [0.025, 0.0, 0.3], # log-90deg
]
debris_spacing_list = [
    [0.6, 0.0, 0.75],   # spacing for 0.3box-0deg
    [0.6, 0.0, 0.70],   # spacing for 0.3box-90deg
    [0.6, 0.0, 0.7625],   # spacing for 0.15box-0deg
    [0.6, 0.0, 0.7375],   # spacing for 0.15box-90deg
    # [0.3, 0.0, 0.025],  # spacing for log-0deg
    # [0.025, 0.0, 0.3],  # spacing for log-90deg
]
# forest density
forest_array_list = [
    [3, 1, 9],  # Conf.1
    [3, 1, 17]  # Conf.2
]
forest_spacing_list = [
    [0.30, 0.0, 0.45],  # Conf.1
    [0.30, 0.0, 0.225],  # Conf.2
]
offset = 0.05  # Column domain_end.x = domain_start.x + offset

# 3) Object 타입 선택
while True:
    object_type = input("🔧 Select object type for Forest Column (Box/Cylinder): ").strip().lower()
    if object_type in ['box', 'cylinder']:
        print(f"✅ Selected object type: {object_type.title()}")
        break
    else:
        print("❌ Please enter 'Box' or 'Cylinder'!")

# 3.5) 센서 추가 여부 선택
while True:
    add_sensors = input("🌊 숲 뒤에 센서 두 개를 추가하시겠습니까? (VelocityMeter3, WG7) (y/n): ").strip().lower()
    if add_sensors in ['y', 'yes', 'n', 'no']:
        if add_sensors in ['y', 'yes']:
            print("✅ 센서 추가: VelocityMeter3, WG7")
            add_sensors = True
        else:
            print("❌ 센서 추가하지 않음")
            add_sensors = False
        break
    else:
        print("❌ Please enter 'y' or 'n'!")

# 4) 파일명 인덱스: 항상 조합 순서 1번부터 (중간 시작 불가 — for 첫 조합 = *_001)
# Object 타입에 따라 다른 폴더 패턴 표시용
if object_type == 'cylinder':
    folder_prefix = 'cyl_in_'
else:
    folder_prefix = 'in_'

# 전체 조합 개수 (중첩 for 순서와 동일)
total_files = (
    len(forest_array_list)
    * len(debris_geo_list)
    * len(forest_loc_list)
    * len(debris_array_list)
)
start_num = 1  # 고정: 첫 번째 조합은 항상 *_001

while True:
    try:
        user_input = input(
            f"📁 Enter ending number (1 ~ {total_files}, suggested: {total_files}, Enter=full): "
        ).strip()
        if user_input == "":
            end_num = total_files
            print(f"✅ Generating all {end_num} cases ({folder_prefix}001 … {folder_prefix}{end_num:03d})")
        else:
            end_num = int(user_input)
            if end_num < start_num:
                print("❌ Ending number must be >= 1!")
                continue
            if end_num > total_files:
                print(
                    f"⚠️  Requested end {end_num} > total combinations {total_files}. Capping to {total_files}."
                )
                end_num = total_files
            print(f"✅ Ending at number: {end_num} ({folder_prefix}001 … {folder_prefix}{end_num:03d})")
        break
    except ValueError:
        print("❌ Please enter a valid number!")

print(f"🎯 Will generate files from {folder_prefix}{start_num:03d} to {folder_prefix}{end_num:03d}")
print(f"📊 Total files to generate: {end_num - start_num + 1}")

file_counter = 0  # 루프 안에서 먼저 +1 하므로 첫 출력은 001

# 5) 모든 조합에 대해 입력 파일 생성 (범위 제한)
# forest_array_list와 forest_spacing_list를 동시에 순회
stop_generation = False
for col_arr, col_sp in zip(forest_array_list, forest_spacing_list):
    if stop_generation:
        break
    for span, debris_spacing in zip(debris_geo_list, debris_spacing_list):
        if stop_generation:
            break
        for x0 in forest_loc_list:
            if stop_generation:
                break
            for arr in debris_array_list:
                file_counter += 1
                
                # 범위를 벗어나면 중단
                if file_counter > end_num:
                    print(f"🛑 Reached ending number {end_num}. Stopping generation.")
                    stop_generation = True
                    break
                # 원본 템플릿 복사
                config = copy.deepcopy(template)

                # gpu=2 & model=1인 body 수정
                for body in config['bodies']:
                    if body.get('gpu') == 2 and body.get('model') == 1:
                        body['geometry'][0]['array'] = arr
                        body['geometry'][0]['span'] = span
                        body['geometry'][0]['spacing'] = debris_spacing

                # Column boundary 수정
                for b in config['boundaries']:
                    if b.get('type') == 'grid' and b.get('name') == 'Forest Column':
                        b['domain_start'][0] = x0
                        b['domain_end'][0]   = round(x0 + offset, 5)
                        b['array']           = col_arr
                        b['spacing']         = col_sp
                        # Object 타입에 따라 Forest Column의 object 변경
                        if object_type == 'cylinder':
                            b['object'] = 'Cylinder'

                # 센서 추가 (숲 위치 + 2.5m 뒤에)
                if add_sensors:
                    # VelocityMeter3 센서 추가 (grid-sensors)
                    velocity_sensor = {
                        "attribute": "Velocity",
                        "direction": "X",
                        "domain_start": [
                            round(x0 + 2.5, 1),
                            1.7,
                            0.0125
                        ],
                        "domain_end": [
                            round(x0 + 2.5 + 0.1, 1),
                            3.0,
                            0.0375
                        ],
                        "name": "VelocityMeter3",
                        "operation": "Average",
                        "output_frequency": 1200,
                        "type": "grid"
                    }
                    config['grid-sensors'].append(velocity_sensor)
                    
                    # WG7 센서 추가 (particle-sensors)
                    wg_sensor = {
                        "type": "particles",
                        "name": "WG7",
                        "attribute": "Elevation",
                        "operation": "Max",
                        "output_frequency": 1200,
                        "domain_start": [
                            round(x0 + 2.5, 1),
                            1.7,
                            0.0125
                        ],
                        "domain_end": [
                            round(x0 + 2.5 + 0.05, 1),
                            3.0,
                            0.0375
                        ]
                    }
                    config['particle-sensors'].append(wg_sensor)

                # Object 타입에 따라 다른 파일명 생성
                if object_type == 'cylinder':
                    folder_name = f"cyl_in_{file_counter:03d}"
                    file_name = f"cyl_in_{file_counter:03d}.json"
                else:
                    folder_name = f"in_{file_counter:03d}"
                    file_name = f"in_{file_counter:03d}.json"
                
                out_name = os.path.join(script_dir, folder_name)
                
                # 폴더 생성
                os.makedirs(out_name, exist_ok=True)
                
                # 입력 파일 저장 
                with open(os.path.join(out_name, file_name), 'w') as fw:
                    json.dump(config, fw, indent=4)
