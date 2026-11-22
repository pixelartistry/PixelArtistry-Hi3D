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
echo        Workflows 01 and 04 make the 3D model from your image first, with TRELLIS.2 or
echo        Pixal3D ^(about 13.8 GB of models, skipped wherever you already have them^).
echo        Workflows 02 and 03 refine a mesh you already have and don't need them.
set "I23D=1"
if /i "%~1"=="NoPause" goto :i23d_done
choice /c YN /n /m "        Install the image-to-3D models for workflows 01 and 04 too? [Y/N] "
if errorlevel 2 set "I23D=0"
:i23d_done

echo.
echo  [4/5] Models - checking ComfyUI\models and extra_model_paths.yaml...
rem The scan uses ComfyUI's own folder logic (python block at the end of this file),
rem so linked folders from Easy-Models-Linker count, and new downloads go to the
rem folder ComfyUI treats as default for each model type.
if exist "%TEMP%\hi3d_models.txt" del "%TEMP%\hi3d_models.txt"
"%PY%" -I -c "import sys;exec(open(sys.argv[1],encoding='utf-8').read().split('#PYMODELS#\n',1)[1])" "%~f0" "%COMFY%" "%TEMP%\hi3d_models.txt" "%WSET%" "%I23D%"
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
rem Next to the other PixelArtistry workflows: sidebar folder "PixelArtistry", subfolder "Hi3D".
rem The workflows are embedded at the end of this file (gzip + base64), so the
rem installer also works on its own, without the "workflows" folder next to it.
rem Workflow 04 (image to game character) also uses nodes from my other packs. It is added
rem either way; if some of those nodes are missing, step 5 lists them in WF04NOTE for the summary.
set "WF=%COMFY%\user\default\workflows\PixelArtistry\Hi3D"
set "WF04NOTE=%TEMP%\hi3d_wf04_missing.txt"
if exist "%WF04NOTE%" del "%WF04NOTE%"
"%PY%" -I -c "import sys;t=open(sys.argv[1],encoding='utf-8').read();exec(t.split('#'+'WORKFLOWS'+'#\n',1)[1].split('#'+'END'+'#',1)[0])" "%~f0" "%WF%" "%TEMP%\hi3d_models.txt" "%CN%" "%WF04NOTE%"
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
echo   2. Workflows sidebar, folder PixelArtistry ^> Hi3D:
echo      "PixelArtistry_Hi3D_01_Image_to_Hi3D"
echo   3. Upload YOUR image in "Upload your image", pick TRELLIS.2 or Pixal3D
echo      with the switch, then Queue. Have a mesh already? Use workflow 02.
echo   4. The coarse and the detailed meshes are saved to ComfyUI\output\hi3d\.
echo.
echo   Workflow 04 goes from an image to a textured low-poly game character
echo   ^(TRELLIS.2 ^> Hi3D ^> low-poly + bake ^> UltraTex^).
if not exist "%WF04NOTE%" goto :wf04_done
echo   It needs more nodes that are NOT installed in this ComfyUI yet:
type "%WF04NOTE%"
echo   Get them, with their models, from my free Animated-Characters installer:
echo     https://github.com/pixelartistry/PixelArtistry-Animated-Characters
echo   Then set the Blender path node in workflow 04 once, and it is ready.
:wf04_done
echo.
echo   License ^(Hi3D Open License v1.0, OCEANO HK HOLDING LIMITED^):
echo   - Commercial use is allowed. Your generated meshes are yours: the licensor
echo     claims no ownership of outputs and you can sell or share them freely.
echo   - Only products or services that integrate Hi3D itself must show
echo     "Powered by Hi3D 1.0", and need a separate license above 200,000
echo     monthly users or USD 1M monthly revenue.
echo   - Follow the Acceptable Use Policy in the LICENSE of AeroX's node folder.
echo   - Workflow 04 only: its UltraTex step runs on FLUX.2 Klein base 9B, which is
echo     licensed for non-commercial use ^(FLUX Non-Commercial License v2.1^).
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
import base64, gzip, json, os, sys
dest, models_txt = sys.argv[2], sys.argv[3]
custom_nodes = sys.argv[4] if len(sys.argv) > 4 else ""
note_file = sys.argv[5] if len(sys.argv) > 5 else ""
os.makedirs(dest, exist_ok=True)
# Workflow 04 also uses nodes this installer does not install (my Animated-Characters pack
# brings them). It is added either way; NEEDS holds one node type per pack, so the installer
# can say which packs are missing.
WF04 = "PixelArtistry_Hi3D_04_Image_to_LowPoly_TRELLIS2_Hi3D_UltraTex.json"
NEEDS = [("LODTailorTheMeshTrimmer", "LODTailor"), ("LODTailorBakeForger", "Bake Forger"),
         ("WTiVoFastMergeByDistance", "Fast Merge"), ("MemoryCleaner", "Memory Cleaner"),
         ("UTXGenerateTextureViewsV23", "UltraTex nodes (MostAadTech's low-VRAM version)"),
         ("UnetLoaderGGUF", "ComfyUI-GGUF")]


def missing_packs():
    """Names from NEEDS whose node type is in no enabled pack under custom_nodes (reads the .py files)."""
    left = dict(NEEDS)
    if not os.path.isdir(custom_nodes):
        return list(left.values())
    hints = ("lodtailor", "bake", "fastmerge", "memory", "ultratex", "gguf")     # likely folders first
    for pack in sorted(os.listdir(custom_nodes), key=lambda d: (not any(h in d.lower() for h in hints), d.lower())):
        root = os.path.join(custom_nodes, pack)
        if not left or pack.endswith(".disabled") or not os.path.isdir(root):
            continue
        for cur, dirs, files in os.walk(root):
            depth = 0 if cur == root else os.path.relpath(cur, root).count(os.sep) + 1
            dirs[:] = [] if depth >= 2 else [d for d in dirs if d[:1] not in "._" and d != "node_modules"]
            for f in files:
                if not left or not f.endswith(".py"):
                    continue
                try:
                    with open(os.path.join(cur, f), encoding="utf-8", errors="ignore") as fh:
                        text = fh.read()
                except OSError:
                    continue
                for key in [k for k in left if '"' + k + '"' in text or "'" + k + "'" in text]:
                    del left[key]
    return list(left.values())


def blender_path():
    """A Blender path that is already set: in an older copy of workflow 04, or in my Animated-Characters workflows."""
    parent = os.path.dirname(dest)
    for p in (os.path.join(dest, WF04),
              os.path.join(parent, "PixelArtistry_05_Image_to_LowPoly_Character_UltraTex.json"),
              os.path.join(parent, "PixelArtistry_05p_Image_to_LowPoly_Prop_UltraTex.json")):
        try:
            with open(p, encoding="utf-8") as fh:
                nodes = json.load(fh).get("nodes", [])
            for n in nodes:
                v = n.get("widgets_values") or [""]
                if (n.get("type") == "PrimitiveString" and str(n.get("title", "")).startswith("Blender path")
                        and isinstance(v[0], str) and v[0].strip() not in ("", "blender")):
                    return v[0].strip(), os.path.basename(p)
        except (OSError, ValueError, AttributeError, IndexError):
            continue
    return None, None


def with_blender(raw, path):
    g = json.loads(raw.decode("utf-8"))
    for n in g["nodes"]:
        if n.get("type") == "PrimitiveString" and n.get("widgets_values") == ["blender"]:
            n["widgets_values"] = [path]
    return json.dumps(g, indent=2, ensure_ascii=False).replace("\n", "\r\n").encode("utf-8")


blender, blender_from = blender_path()
for old in ("PixelArtistry_Hi3D_01_Refine_Chain_512-1024-1536.json", "PixelArtistry_Hi3D_02_Refine_Single_Pass.json"):
    op = os.path.join(dest, old)
    if os.path.exists(op):
        os.replace(op, op + ".bak")
        print("       " + old + " - renamed in this version, old file kept as .bak")
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
    ("PixelArtistry_Hi3D_01_Image_to_Hi3D.json", (
        "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"
        "ATMgOhuQJgEA"
    )),
    ("PixelArtistry_Hi3D_02_Your_Mesh_Refine_Chain_512-1024-1536.json", (
        "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"
    )),
    ("PixelArtistry_Hi3D_03_Your_Mesh_Single_Pass.json", (
        "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"
    )),
    ("PixelArtistry_Hi3D_04_Image_to_LowPoly_TRELLIS2_Hi3D_UltraTex.json", (
        "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"
        "8v8Bqin81IYwAgA="
    )),
]
for name, data in FILES:
    path = os.path.join(dest, name)
    raw = gzip.decompress(base64.b64decode(data)).replace(b"hi3d_v1_int8.safetensors", ckpt.encode())
    if name == WF04 and blender:
        try:
            raw = with_blender(raw, blender)
        except Exception:
            blender = None
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
if any(name == WF04 for name, _data in FILES):
    gone = missing_packs()
    if gone:
        print("       Workflow 04 needs %d more node pack(s) that are not installed here - see the end." % len(gone))
        if note_file:
            with open(note_file, "w", encoding="utf-8") as fh:
                fh.write("".join("     - " + g + "\n" for g in gone))
    else:
        print("       Workflow 04: the extra nodes it needs (LODTailor, Bake Forger, UltraTex ...) are installed.")
    if blender:
        print("       Workflow 04: Blender path taken from " + blender_from + ".")
    else:
        print("       Workflow 04: set its Blender path node once before the first run.")
#END#

rem ==========================================================================
rem  Python: model scan (read by step 4, never run by cmd)
rem ==========================================================================
#PYMODELS#
import os, sys, logging
comfy, out, wset = sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "1"
i23d = len(sys.argv) <= 5 or sys.argv[5] != "0"
sys.path.insert(0, comfy)
os.chdir(comfy)
logging.disable(logging.CRITICAL)
import folder_paths
for extra in ("geometry_estimation",):
    if extra not in folder_paths.folder_names_and_paths:
        folder_paths.add_model_folder_path(extra, os.path.join(folder_paths.models_dir, extra))
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
T2 = "https://huggingface.co/Comfy-Org/TRELLIS.2/resolve/430a9d09b2416687018c8fe8edced2ad4858a439/"
PX = "https://huggingface.co/Comfy-Org/Pixal3D/resolve/f37641be376725d324c56626007cc477f1249a69/"
MOGE = "https://huggingface.co/Comfy-Org/MoGe/resolve/1484985258ba7ef45c314144fcf0e90924ffbf44/"
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
I23D_MODELS = [
    ("T2", "trellis_2_int8_convrot.safetensors", "diffusion_models", 5253048192,
     "d01952ad137213f6a868f86b6b877026276f84af5eec23069217475a0bad3a31", T2 + "diffusion_models/trellis_2_int8_convrot.safetensors",
     "TRELLIS.2 int8 - 5.3 GB"),
    ("T2VAE", "trellis_2_shape_vae_bf16.safetensors", "vae", 1095844024,
     "de0cb4949a76c59ee5c091a995a69bcc8c51d5aeda939f0c641a50d2a72341f4", T2 + "vae/trellis_2_shape_vae_bf16.safetensors",
     "TRELLIS.2 shape VAE - 1.1 GB"),
    ("DINO3", "dino_v3_L_naf_fp32.safetensors", "clip_vision", 1215214176,
     "4ad2ec4e0879a5b5b04cd97325cc37da954a7b6edca5170b86510f17f2b2290f", PX + "clip_vision/dino_v3_L_naf_fp32.safetensors",
     "DINOv3 - 1.2 GB"),
    ("PX", "pixal3d_int8_convrot.safetensors", "diffusion_models", 5584555824,
     "4621eac3b715484f79303c7152af641fe0b2b14f4d0e3d394fd6922d00f955ec", PX + "diffusion_models/pixal3d_int8_convrot.safetensors",
     "Pixal3D int8 - 5.6 GB"),
    ("MOGE", "moge_2_vitl_normal_fp16.safetensors", "geometry_estimation", 661859924,
     "cb1a692d03235671e959e81360d7b4d9f44aefadb1f852d6ca6aa17799d5e31f", MOGE + "geometry_estimation/moge_2_vitl_normal_fp16.safetensors",
     "MoGe 2 - 0.7 GB"),
]
if i23d:
    MODELS += I23D_MODELS
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
