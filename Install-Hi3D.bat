@echo off
setlocal
title PixelArtistry - Hi3D Installer
chcp 65001 >nul

rem ==========================================================================
rem  Hi3D one-click installer for ComfyUI (Windows, portable / Easy-Install)
rem  by PixelArtistry - free on github.com/pixelartistry
rem
rem  Nodes:   Aero-Ex/Aero-Ex-ComfyUI-Hi3D, pinned to the tested commit
rem  Weights: Aero-Ex/ComfyUI-Hi3D on Hugging Face (Hi3D Open License v1.0)
rem
rem  Works from any of these places - just double-click it there:
rem    - ComfyUI-Easy-Install\Add-Ons\PixelArtistry-Hi3D-main\   (the unzipped repo)
rem    - ComfyUI-Easy-Install\Add-Ons\        (as an Easy-Install add-on)
rem    - the folder that contains "python_embeded" and "ComfyUI"
rem    - the ComfyUI folder itself
rem  Close ComfyUI first. Safe to re-run: existing files are skipped,
rem  unfinished downloads resume. Pass NoPause to skip all questions
rem  (int8 weights, download yes) and the final pause.
rem ==========================================================================

set "COMMIT=227d18f4fb8938e73ef5f4675a3656aa8d337f76"
set "NODE_REPO=https://github.com/Aero-Ex/Aero-Ex-ComfyUI-Hi3D"
set "NODE_ZIP=https://codeload.github.com/Aero-Ex/Aero-Ex-ComfyUI-Hi3D/zip/%COMMIT%"
set "NODE_NAME=Aero-Ex-ComfyUI-Hi3D"

echo.
echo  ============================================================
echo    Hi3D for ComfyUI - one-click installer by PixelArtistry
echo    Nodes and 6 GB weights by AeroX
echo  ============================================================
echo.

rem ---------------------------------------------------------------- 1. find ComfyUI
set "ROOT="
if exist "%~dp0python_embeded\python.exe" if exist "%~dp0ComfyUI\main.py" set "ROOT=%~dp0."
if not defined ROOT if exist "%~dp0..\python_embeded\python.exe" if exist "%~dp0..\ComfyUI\main.py" set "ROOT=%~dp0.."
if not defined ROOT if exist "%~dp0..\python_embeded\python.exe" if exist "%~dp0main.py" set "ROOT=%~dp0.."
rem The unzipped repo folder inside Add-Ons: Add-Ons\PixelArtistry-Hi3D-main\Install-Hi3D.bat
if not defined ROOT if exist "%~dp0..\..\python_embeded\python.exe" if exist "%~dp0..\..\ComfyUI\main.py" set "ROOT=%~dp0..\.."
if not defined ROOT (
    echo  [ERROR] Could not find "python_embeded" and "ComfyUI" next to this file.
    echo          Put Install-Hi3D.bat into ComfyUI-Easy-Install\Add-Ons, or into the
    echo          folder that contains python_embeded, and run it again.
    goto :fail
)
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "PY=%ROOT%\python_embeded\python.exe"
set "COMFY=%ROOT%\ComfyUI"
set "CN=%COMFY%\custom_nodes"
set "NODE_DIR=%CN%\%NODE_NAME%"
set "WARN=%TEMP%\hi3d_install_warnings.txt"
if exist "%WARN%" del "%WARN%"

echo  ComfyUI found: %COMFY%

rem ComfyUI must be closed while nodes and models are installed.
rem Port: the --port value in "Start ComfyUI.bat" (Easy-Install root), else 8188.
set "PORT="
if exist "%TEMP%\hi3d_port.txt" del "%TEMP%\hi3d_port.txt"
if exist "%ROOT%\Start ComfyUI.bat" "%PY%" -I -c "import sys,re;t=open(sys.argv[1],errors='ignore').read();m=re.findall(r'^(?!\s*(?:rem|::)).*?--port[= ]+(\d+)',t,re.M|re.I);print(m[-1] if m else '')" "%ROOT%\Start ComfyUI.bat" > "%TEMP%\hi3d_port.txt" 2>nul
if exist "%TEMP%\hi3d_port.txt" set /p PORT=<"%TEMP%\hi3d_port.txt"
if not defined PORT set "PORT=8188"
netstat -ano | findstr /r /c:":%PORT% .*LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo  [ERROR] ComfyUI seems to be running on port %PORT%. Close it first, then run this again.
    goto :fail
)

"%PY%" -c "import torch;print(torch.__version__)" > "%TEMP%\hi3d_torch.txt" 2>nul
set "TV="
set /p TV=<"%TEMP%\hi3d_torch.txt"
if not defined TV (
    echo  [ERROR] PyTorch is not working in python_embeded. Fix your ComfyUI install first.
    goto :fail
)
echo  PyTorch:       %TV%

rem ---------------------------------------------------------------- 2. ComfyUI version
echo.
echo  [1/5] Checking ComfyUI version...
set "CV="
"%PY%" -I -c "import re,sys;t=open(sys.argv[1]).read();print(re.search(r'__version__\s*=\s*[\x22\x27]([^\x22\x27]+)',t).group(1))" "%COMFY%\comfyui_version.py" > "%TEMP%\hi3d_cv.txt" 2>nul
set /p CV=<"%TEMP%\hi3d_cv.txt"
if not defined CV (
    echo        Could not read the ComfyUI version - continuing.
    >>"%WARN%" echo  - ComfyUI version unknown. Hi3D needs ComfyUI v0.42.0 or newer.
    goto :version_done
)
"%PY%" -I -c "import sys;v=tuple(int(x) for x in sys.argv[1].split('-')[0].split('.')[:3]);sys.exit(0 if v>=(0,42,0) else 1)" "%CV%"
if errorlevel 1 (
    echo.
    echo  [ERROR] Your ComfyUI is v%CV%. Hi3D needs v0.42.0 or newer
    echo          ^(the nodes use ComfyUI's new 3D mesh functions^).
    echo          Update ComfyUI first, then run this installer again:
    echo            Easy-Install:  "Update ComfyUI.bat" in the Easy-Install folder
    echo            Portable:      update\update_comfyui.bat
    goto :fail
)
echo        OK - ComfyUI v%CV%
:version_done

rem ---------------------------------------------------------------- 3. nodes
echo.
echo  [2/5] Installing AeroX's Hi3D nodes ^(commit %COMMIT:~0,7%^)...
rem Two copies of the same pack register the same nodes and conflict.
"%PY%" -I -c "import os,sys;cn,own=sys.argv[1],sys.argv[2];[print(d) for d in sorted(os.listdir(cn)) if d!=own and not d.endswith('.disabled') and os.path.isfile(os.path.join(cn,d,'nodes_hi3d.py')) and 'Hi3DCheckpointLoader' in open(os.path.join(cn,d,'nodes_hi3d.py'),errors='ignore').read()]" "%CN%" "%NODE_NAME%" > "%TEMP%\hi3d_dupes.txt" 2>nul
for /f "usebackq delims=" %%D in ("%TEMP%\hi3d_dupes.txt") do (
    echo        WARNING - another copy of AeroX's Hi3D nodes is installed: custom_nodes\%%D
    >>"%WARN%" echo  - Two copies of AeroX's Hi3D nodes: delete custom_nodes\%%D, keep %NODE_NAME%.
)
where git >nul 2>&1
if errorlevel 1 goto :nodes_zip
if exist "%NODE_DIR%\.git" (
    git -C "%NODE_DIR%" fetch --quiet origin
) else (
    if exist "%NODE_DIR%" rmdir /s /q "%NODE_DIR%"
    git clone --quiet "%NODE_REPO%" "%NODE_DIR%"
)
git -C "%NODE_DIR%" checkout --quiet --force %COMMIT%
if errorlevel 1 (
    echo  [ERROR] git could not check out the tested commit.
    goto :fail
)
goto :nodes_done

:nodes_zip
echo        git not found - downloading the pinned version as a zip instead.
if exist "%NODE_DIR%" rmdir /s /q "%NODE_DIR%"
curl -L --fail -s -o "%TEMP%\hi3d_nodes.zip" "%NODE_ZIP%"
if errorlevel 1 (
    echo  [ERROR] Download of the nodes failed. Check your internet connection.
    goto :fail
)
if exist "%TEMP%\hi3d_nodes" rmdir /s /q "%TEMP%\hi3d_nodes"
mkdir "%TEMP%\hi3d_nodes"
tar -xf "%TEMP%\hi3d_nodes.zip" -C "%TEMP%\hi3d_nodes"
move "%TEMP%\hi3d_nodes\%NODE_NAME%-%COMMIT%" "%NODE_DIR%" >nul
if not exist "%NODE_DIR%\nodes_hi3d.py" (
    echo  [ERROR] Could not unpack the nodes.
    goto :fail
)

:nodes_done
echo        OK - %NODE_DIR%
echo        No extra Python packages needed: the nodes only use ComfyUI itself.

rem ---------------------------------------------------------------- 4. models
echo.
echo  [3/5] Hi3D weights - int8 or fp16?
set "VRAM_MB="
for /f "tokens=1" %%v in ('nvidia-smi --query-gpu^=memory.total --format^=csv^,noheader^,nounits 2^>nul') do if not defined VRAM_MB set "VRAM_MB=%%v"
if defined VRAM_MB echo        Your GPU: %VRAM_MB% MB VRAM
echo.
echo          1 = int8  ^(4.3 GB download^)  recommended, runs on 6 GB GPUs
echo          2 = fp16  ^(7.7 GB download^)  same quality, a bit faster on 16 GB GPUs
echo          3 = both
set "WSET=1"
if /i "%~1"=="NoPause" goto :wset_done
choice /c 123 /n /m "        Which weights? [1/2/3] "
set "WSET=%errorlevel%"
:wset_done

echo.
echo  [4/5] Models - checking ComfyUI\models and extra_model_paths.yaml...
rem The scan uses ComfyUI's own folder logic (python block at the end of this file),
rem so linked folders from Easy-Models-Linker count, and new downloads go to the
rem folder ComfyUI treats as default for each model type.
if exist "%TEMP%\hi3d_models.txt" del "%TEMP%\hi3d_models.txt"
"%PY%" -I -c "import sys;exec(open(sys.argv[1],encoding='utf-8').read().split('#PYMODELS#\n',1)[1])" "%~f0" "%COMFY%" "%TEMP%\hi3d_models.txt" "%WSET%"
if not exist "%TEMP%\hi3d_models.txt" (
    echo  [ERROR] Could not check the model folders. Scroll up for the error.
    goto :fail
)
findstr /b "NEED|" "%TEMP%\hi3d_models.txt" >nul 2>&1
if errorlevel 1 (
    echo.
    echo        All models are already there.
    goto :workflows
)
echo.
if /i "%~1"=="NoPause" goto :do_models
choice /c YN /n /m "        Download the missing models now? [Y/N] "
if errorlevel 2 (
    echo        Skipped. Run the installer again any time to download them.
    >>"%WARN%" echo  - Models not downloaded ^(you chose N^). Re-run the installer to get them.
    goto :workflows
)
:do_models
for /f "usebackq tokens=1-5,* delims=|" %%a in ("%TEMP%\hi3d_models.txt") do (
    if "%%b"=="MISSING" call :download "%%e" "%%f" "%%c" "%%d"
)

rem ---------------------------------------------------------------- 5. workflows
:workflows
echo.
echo  [5/5] Adding workflows to the ComfyUI workflow browser...
rem Same place as the other PixelArtistry workflows: sidebar folder "PixelArtistry".
rem The workflows are embedded at the end of this file (gzip + base64), so the
rem installer also works on its own, without the "workflows" folder next to it.
set "WF=%COMFY%\user\default\workflows\PixelArtistry"
"%PY%" -I -c "import sys;t=open(sys.argv[1],encoding='utf-8').read();exec(t.split('#'+'WORKFLOWS'+'#\n',1)[1].split('#'+'END'+'#',1)[0])" "%~f0" "%WF%" "%TEMP%\hi3d_models.txt"
if errorlevel 1 >>"%WARN%" echo  - Could not write the PixelArtistry workflows to %WF%.

rem ---------------------------------------------------------------- summary
echo.
echo  ============================================================
if exist "%WARN%" (
    echo   Finished with warnings:
    type "%WARN%"
) else (
    echo   Everything installed.
)
echo  ============================================================
echo.
echo   Next steps:
echo   1. Start ComfyUI.
echo   2. Workflows sidebar, folder PixelArtistry:
echo      "PixelArtistry_Hi3D_01_Refine_Chain_512-1024-1536"
echo   3. Upload YOUR coarse mesh in "Load Coarse Mesh" and YOUR reference image
echo      ^(ideally the image the mesh was made from^), then Queue.
echo   4. The detailed meshes are saved to ComfyUI\output\hi3d\.
echo.
echo   License ^(Hi3D Open License v1.0, OCEANO HK HOLDING LIMITED^):
echo   - Commercial use is allowed. Your generated meshes are yours: the licensor
echo     claims no ownership of outputs and you can sell or share them freely.
echo   - Only products or services that integrate Hi3D itself must show
echo     "Powered by Hi3D 1.0", and need a separate license above 200,000
echo     monthly users or USD 1M monthly revenue.
echo   - Follow the Acceptable Use Policy in the LICENSE of AeroX's node folder.
echo     This is not legal advice.
echo.
if /i not "%~1"=="NoPause" pause
exit /b 0

:fail
echo.
echo  Installation stopped. Nothing else was changed.
echo.
if /i not "%~1"=="NoPause" pause
exit /b 1


rem ==========================================================================
rem  Subroutines
rem ==========================================================================

:download
rem %1 = url, %2 = target file, %3 = expected sha256, %4 = label
rem Downloads to <file>.part (resumable), checks the SHA-256, renames when complete.
echo.
echo        %~4...
if not exist "%~dp2" mkdir "%~dp2"
curl -L --fail -C - --retry 3 -o "%~2.part" "%~1"
if not errorlevel 1 goto :download_check
rem A broken or already-complete .part makes resuming fail - start that file over once.
if exist "%~2.part" (
    echo        Resume failed - restarting this download from scratch...
    del "%~2.part"
    curl -L --fail --retry 3 -o "%~2.part" "%~1"
    if not errorlevel 1 goto :download_check
)
echo        Download failed:
echo          from: %~1
echo          to:   %~2
>>"%WARN%" echo  - %~4 download failed. Re-run the installer to resume it.
exit /b 1
:download_check
echo        Checking the file ^(SHA-256^)...
"%PY%" -I -c "import hashlib,sys;h=hashlib.sha256();f=open(sys.argv[1],'rb');[h.update(b) for b in iter(lambda:f.read(1<<24),b'')];sys.exit(0 if h.hexdigest()==sys.argv[2] else 1)" "%~2.part" "%~3"
if errorlevel 1 (
    echo        The downloaded file is damaged - deleted. Run the installer again.
    del "%~2.part"
    >>"%WARN%" echo  - %~4 was damaged ^(SHA-256 mismatch^) and deleted. Re-run the installer.
    exit /b 1
)
move /y "%~2.part" "%~2" >nul
if not exist "%~2" exit /b 1
echo        Saved: %~2
exit /b 0

rem ==========================================================================
rem  The PixelArtistry workflows (gzip + base64) for step 5.
rem  cmd never runs the lines below; step 5 unpacks them with Python.
rem ==========================================================================
#WORKFLOWS#
import base64, gzip, os, sys
dest, models_txt = sys.argv[2], sys.argv[3]
os.makedirs(dest, exist_ok=True)
# Point the checkpoint loader at the weights that are actually there (int8 preferred).
have = set()
if os.path.isfile(models_txt):
    for line in open(models_txt, encoding="utf-8"):
        parts = line.rstrip("\n").split("|")
        if len(parts) > 1 and parts[1] == "FOUND":
            have.add(parts[0])
ckpt = "hi3d_v1_int8.safetensors"
if "FP16" in have and "INT8" not in have:
    ckpt = "hi3d_v1.safetensors"
FILES = [
    ("PixelArtistry_Hi3D_01_Refine_Chain_512-1024-1536.json", (
        "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"
    )),
    ("PixelArtistry_Hi3D_02_Refine_Single_Pass.json", (
        "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"
    )),
]
for name, data in FILES:
    path = os.path.join(dest, name)
    raw = gzip.decompress(base64.b64decode(data)).replace(b"hi3d_v1_int8.safetensors", ckpt.encode())
    note = ""
    if os.path.exists(path):
        with open(path, 'rb') as fh:
            if fh.read() == raw:
                print("       " + name + " - up to date.")
                continue
        os.replace(path, path + ".bak")
        note = " - updated, your previous version is saved as " + name + ".bak"
    with open(path, 'wb') as fh:
        fh.write(raw)
    print("       " + name + note)
if ckpt != "hi3d_v1_int8.safetensors":
    print("       (set to the fp16 weights hi3d_v1.safetensors)")
#END#

rem ==========================================================================
rem  Python: model scan (read by step 4, never run by cmd)
rem ==========================================================================
#PYMODELS#
import os, sys, logging
comfy, out, wset = sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "1"
sys.path.insert(0, comfy)
os.chdir(comfy)
logging.disable(logging.CRITICAL)
import folder_paths
if "background_removal" not in folder_paths.folder_names_and_paths:
    folder_paths.add_model_folder_path("background_removal", os.path.join(folder_paths.models_dir, "background_removal"))
yaml_path = os.path.join(comfy, "extra_model_paths.yaml")
if os.path.isfile(yaml_path):
    try:
        from utils.extra_config import load_extra_path_config
        load_extra_path_config(yaml_path)
        print("       Found extra_model_paths.yaml - linked model folders are included.")
    except Exception as e:
        print("       WARNING: could not read extra_model_paths.yaml:", e)
else:
    print("       No extra_model_paths.yaml - checking ComfyUI\\models only.")

HF = "https://huggingface.co/Aero-Ex/ComfyUI-Hi3D/resolve/10e577aabc5c3c748f56b1fcc91178f581039312/"
BIREF = "https://huggingface.co/Comfy-Org/BiRefNet/resolve/884af709e9b795d89dafbf97f29c8d6a2386f5c6/"
# key, file, folder type, size, sha256, url, label
MODELS = [
    ("INT8", "hi3d_v1_int8.safetensors", "checkpoints", 4320712680,
     "b9eb785f7adf47208223a9262a593df6a1645f790a7c452a5e1f79440498af89", HF + "checkpoints/hi3d_v1_int8.safetensors",
     "Hi3D int8 - 4.3 GB"),
    ("FP16", "hi3d_v1.safetensors", "checkpoints", 7728024728,
     "4ab3accc886a8e1ffc799c07d111aa08e1b91b21579730a7e56e4ea626644bfb", HF + "checkpoints/hi3d_v1.safetensors",
     "Hi3D fp16 - 7.7 GB"),
    ("DINO", "dinov2-large.safetensors", "clip_vision", 1217522888,
     "399fba97a95f22c36834418bc69373364a99af3a1153da1c0fb31db567c92e23", HF + "clip_vision/dinov2-large.safetensors",
     "DINOv2-large - 1.2 GB"),
    ("CLIP", "clip-vit-large-patch14.safetensors", "clip_vision", 1710540580,
     "a2bf730a0c7debf160f7a6b50b3aaf3703e7e88ac73de7a314903141db026dcb", HF + "clip_vision/clip-vit-large-patch14.safetensors",
     "CLIP ViT-L/14 - 1.7 GB"),
    ("BIREF", "birefnet.safetensors", "background_removal", 444473596,
     "9ab37426bf4de0567af6b5d21b16151357149139362e6e8992021b8ce356a154", BIREF + "background_removal/birefnet.safetensors",
     "BiRefNet background removal - 0.4 GB"),
]
wanted = {"1": {"INT8"}, "2": {"FP16"}, "3": {"INT8", "FP16"}}.get(wset, {"INT8"})


def find(name, kind):
    name = name.lower()
    for d in folder_paths.get_folder_paths(kind):
        if not os.path.isdir(d):
            continue
        for root, _dirs, files in os.walk(d, followlinks=True):
            for f in files:
                if f.lower() == name:
                    return os.path.join(root, f)
    return None


lines, missing = [], 0
print()
for key, name, kind, size, sha, url, label in MODELS:
    hit = find(name, kind)
    if hit:
        note = ""
        if os.path.getsize(hit) != size:
            note = "   (different size than AeroX's file - if Hi3D fails, delete it and re-run)"
        print("       found    %-38s %s%s" % (label, hit, note))
        lines.append("%s|FOUND|||%s" % (key, hit))
        continue
    if key in ("INT8", "FP16") and key not in wanted:
        continue
    # resume an unfinished download (.part) wherever it already is
    target = os.path.join(folder_paths.get_folder_paths(kind)[0], name)
    for d in folder_paths.get_folder_paths(kind):
        if os.path.isfile(os.path.join(d, name + ".part")):
            target = os.path.join(d, name)
            break
    print("       MISSING  %-38s -> %s" % (label, target))
    lines.append("%s|MISSING|%s|%s|%s|%s" % (key, sha, label, url, target))
    missing += 1
if missing:
    lines.append("NEED|1|")
with open(out, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
