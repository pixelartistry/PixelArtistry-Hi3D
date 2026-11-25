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
echo   Without them, workflow 04 shows red nodes and stops with an error like
echo   "Node 'ID #353' has no class_type". ComfyUI Manager cannot install them all.
echo   Get them, with their models, from my free Animated-Characters installer:
echo     https://github.com/pixelartistry/PixelArtistry-Animated-Characters
echo   ^(The standard UltraTex install is not enough: workflow 04 uses MostAadTech's
echo   low-VRAM UltraTex nodes.^) Then set the Blender path node in workflow 04 once.
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
