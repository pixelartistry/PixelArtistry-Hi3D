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
echo        Workflow 01 makes the 3D model from your image first, with TRELLIS.2 or Pixal3D
echo        ^(about 13.8 GB of models, skipped wherever you already have them^).
echo        Workflows 02 and 03 refine a mesh you already have and don't need them.
set "I23D=1"
if /i "%~1"=="NoPause" goto :i23d_done
choice /c YN /n /m "        Install the image-to-3D models for workflow 01 too? [Y/N] "
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
set "WF=%COMFY%\user\default\workflows\PixelArtistry\Hi3D"
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
echo   2. Workflows sidebar, folder PixelArtistry ^> Hi3D:
echo      "PixelArtistry_Hi3D_01_Image_to_Hi3D"
echo   3. Upload YOUR image in "Upload your image", pick TRELLIS.2 or Pixal3D
echo      with the switch, then Queue. Have a mesh already? Use workflow 02.
echo   4. The coarse and the detailed meshes are saved to ComfyUI\output\hi3d\.
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
        "H4sIAAAAAAAC/+1dbW/bSJL+vsD+B0IL3E6wFtPvLz5gAcd2Mt5x7KztZHfvZiDQUsvmRSK1JG0n"
        "M8h/v2rKskiKpERa8mhn5ACxyW52Vxefqu6qp0n+8sc/OE7HH3T2nc41U7xv+v2uR4f9LhPiuusZ"
        "dd1FgrP+QFz3r7np7KUXRObej/0wgMvQ9MzIi5NeEA5ML22MqMzpkR98np5mZHraVozh+H/tkeP8"
        "Mv01kwTvPR0nXyfGyva9T48Ob03/8yT0g+Q09AYm6syrTcJMa/aHob3swezvn+aXxP7PJn8NpdmL"
        "MCq7ajjybmxXv3ybnwsjK8xME+mpMYwvf8YPJndJKmSmtfAumZ2dd/zL/E+rKW+cKuD9+dHxaWcv"
        "VzZTTlmZ1Xmh4XRUdC9/ghRPUJo9/ml+8G1vmYyfDo4rJFwsqZJPFeUrnqCqSr6S2zWJwomJEj8F"
        "W0bozhncIMfK7QzDyLn8r4tKkM0uytzwB39wY5K4d++N7kxhEJ1bnw5697gHLSg39oYmMUEcRnGn"
        "RLx8Qz0rz6AgKAiT9GYKXtr2ow5mshbsiiza1eHpyYdPqSk3tCms2xiVaGpTeJM2ZQff+3RyeXJ+"
        "VoHb6hoV+BUNwJn4ySjtxareOTo5O78nnbbYXbiRTXE78IPwnnRHXnRj1oHbkT95wu3StutxS9eI"
        "W4peBLfkPwy3sjVubVfOJ/+qe/oas18PvhZv3Xs/mYKsO/GS/i1m6wZyg17qIc0WIW0HfjL2bszq"
        "6xrcBstUNQUz3SSYT94fvKtaNpSVVS0cisuE1quY9weXP1QttBaLnsRZ1WguzNBEJugbZ+FmN7KY"
        "OVyamor54o0nI+NOgpvsYDp+rrVmVjK9dr+68bvJCAS2NfLd1JsJLzeTN17/800U3gWDCzMOQaz3"
        "oKFRvd20Mhz0rEmAbdJurm964/yoc2p6c3D4w7uL849nR72L4/fnnw5WDBDIxlbXNTeuKYKv/cgM"
        "A5Oswb2DGqOpKE9Ovrb1eryKRbymAzXzga+OUk7aoJQ3RalcDaUr4HGmyGfj0i6gmrhsP+9JV5pD"
        "bHBRD+8Gxjj24s8t5oy86bGNmd4CBldDs1xEczrjHELnV+H73JiXgVm0AjOWrCGa9XrQnCIqbg4p"
        "2gS2FjVxM9jYWWVtqG01yBLgbi4jU4Rbw4kCI8L2qg9dkjnKwq7zp2H603JOgSrJrfUv+f46t8a/"
        "uU1KCibeoDf0+kmYpjxyYnXAYh96qX/Zz8t4PTfn/UWJ6y1bV2RYw2DgJxCE+dnV26JpS/r8VJBu"
        "nArC6zFtm4zoPaav20TPdppvYuVpAPm8/uQLTIZqbW4F4AIguq+S4fD87OjkCsZ6cvZuxdgOFZPC"
        "xRMUtQ73AnPjrVfaYihKFmJTvNkUdtaKV/MHGQ3nAi16VOcGulJJV0shJVMYM65Fdh2qXM0lhlWA"
        "YERzItqkKiRp6CT4JkOuNpa1kBvY29BaslkfJr7tTTyYpco7ury6qMF7M/sKo7E32rjW+vA78np+"
        "MAwr+jo9PziiR73Dg/fHFwdr6TMyfcAdWBm494Gp6vfTydHx+Xrumo2renRQ0dHbk9PjXtZi67yU"
        "bu0wZ1KsoOuUmOydnL09f27WbJpqDr0oNs57AO8qabMLE4d3Ud84b8PR1Dt0cimpyixFXoedwxRa"
        "0Hsw9G/yfTgz4F09DhwkiSemXzKhDMN7Gx/w/NlbLz68i5Nw/HECpUNvFJt8hTjxElPs1JlNsikD"
        "XyiCwi/pMpIRRCQlTGDEFSryvFDtq42zXS6oEIojjCXmSrPFej+nzWkqpSQYa4GQUpznq30rXNZJ"
        "bIY8qRQPVYmDOCcKgzhCK85QhThoSe8/h+E4Rx82u1tQ8993oPgoqFNxF7lIKw0zHxKCaaSQKh8V"
        "cinSFBMFE6UmSGPJK4blIkooTKhEgQIgZsZILNZ8SGtqxglTCEnBNWKKLdFIKf7gvJdqoExXgfGi"
        "qUwLRcO0BCOE0EJRBHi+G5cqbWSGtqduyeijx9CopCgJJ+UF12GSpLe5WwRj9vBbuXPrnNoeq6za"
        "D2ziz0++5uiPqckOIr/EIE3gXY/SUHDRih+v+uClYWFnAWvxbfhwEL/JBnSljWSlwquM8bJvAlM1"
        "Rtvruyhd/yXRXcHvzKPLw3CUxqWdPxFl/3WqKp7MOIDKGhcmAEf8frowA+du9ZWvm04uJdPVIpbq"
        "HODMx7iAT8q4wpQJoiUmYKmLDiXnerBm4OiEJEyXVXw0UkwR1VCbSQZNUkKKVb8torXeoVS6xZkL"
        "qZSmrOChCJAKmeK+NzI14nDQIAYvLLgCr8+ZqhJvpYo/l1VckLLGlCvWKZ2URaiC+d3kyI+sk08V"
        "D5GCf+MHCyvSsb05/pSQqKlmbebysxmZJG2tZMK+8X8eh839w3hmFJEXxCM75+81nfFXhPuKYF8R"
        "6gvzTBTCiqVWzIo5st1EX4ngFfG7InpXwW7lrNOU3grCwJSQp3SwQKw8lhx/AdjMlru5hG6nP7Kz"
        "ePZMZ682Qdou5TkNCob+6DHmKx2AQwfOdAj7y8fkGDsoJ3oa1f7Ko90vG7ZfNjutlqpdMYdSsm31"
        "nUlsPmY8AYUESVybTIFlXy6ZwteQTXkeM6jWk3BdLWztvTt9szf/++rt08H5m789/X15dbpXHefa"
        "zPb6OL1cmJnPwxxffr8ip4c2luorYmtFlJLy1P+FGfqBuUyW7D/CEMS4dj7gksC8ILKrci5cqQG6"
        "lBOYfZRgq2FU5LgE3JgWIOtB6fOy1qmneLm0c+pumib8moE53a2/xZwA26KMP28ty+nB1fHZVVUW"
        "raywSgaxUU4h6x6aLmc4Ji2JVDv5j+5mK/dsO0ucHC13cpfp3rRoiYNjLgb3haTEEtHcAxMEE5dr"
        "SgWzWRwtMGnj4oRo6uLoGifihs+QpN03QfTz/Sh7WT/Km3RnI7MgaWqvthuxNl+6Pp8hN+ozZtbW"
        "0F+w3PaHof8lnyQivJ0viY3JPIE2ixfCIInCUc8bQvTfuzGBiabp9sV+O3FiJlbUuQBLnFDJHu9P"
        "B8dHpg8Ks/pZ4oYIrKYUp4qBLwJvk92+SrHLhYRFGBVcg5PiLdxQ42gAs/V4oTiFRdzGhhrtg7j3"
        "TKOn0WwH69sEUbKqah494GJahmxue24emitCvGR/9qV3byCUWwJu4cL0SZTUMJVyJrO4lMiVTADm"
        "NUzBkrXBNmv8iAPma5pi69fZe42C3bdv/lkW+PY+Xh79z9PBh9N/zSt9APPJHM1r/VAsgqPewdn8"
        "0g/nJ2dXvcPT849H2fMVdrJ6lN0ajws4spSNFyfOlQ8Vpxnft4/5Jvtc5OsoXaIOerBM7FliSvbc"
        "m9F1/fVPxPBU4t8A7YtcwaVggkrFFZEIy/KUJ7WLXEG0UppQqkRFylO6CHGOqBRaMyoE3hjrCwaP"
        "tWU9Ncx5fMtZX5ATaWbVwjDhSlbRvogJQcGRCckUoUjiat4XGuNYY4YZI0IwpCt5X82FklwjxQlW"
        "mD+b93URTQUEWQlgR+544B0P/NvigZuTqr9RPhdXiYOrxME7fnZt/Oxaic+t4llxeV+4Yi/ZhnjT"
        "4jIwT3u2SxtYStOe701sw1/KVpsVNOOKIZR4Hh/DFXM5IgpWJJIyhnOkIXJhdYdhYQFrCoXJqqzh"
        "cxkZsSWMDHlZRoZsnpEhW8zIkC1iZMgWMDJkexkZu6lhLZRMrqEljk6252TqnBwhzBWKc8kV1hq/"
        "GCcjf1VOhrwsJ0NelpMhL8PJkC3kZMiOk9kkJ6Oew8lw+7gbLPi4tOlpIrNuiDHhMoygmGEuhJb0"
        "RTgZ9WtzMmTTnAzZMk6GFBNzdMs4Gd2Ok+EaogVEudCUEcxQjpNRyKVCcKIkp1pq/DKcjN5xMqtz"
        "MmSbORm7TkxJGfE7JWUQhXkBIWp/MCWYVLEyMKtw+wQYF5TAgrc8gcJcxTQlDIyRMKTI5h7GE4gL"
        "YtMHGtvdBttNy2BCuH3uQWOsiNCq8mk8uBEkZVoElVozmyGp5mXsNldFEGP2CUnwYpxWMzMk3beN"
        "IBahmLAdM7NjZnbMzI6Z2TEzO2Zmx8zkFoMvQc0s9NOUmyHoWdwMQZzDmsA+EgOTtyD5kAq7HIIt"
        "WBEjWIGIVls4m1MzBG0JNUNflpqhm6dm6BZTM3SLqBm6BdQM3WJqBqKs9VAz2YaW+Dncmpqp9XEE"
        "a1dTCMaEJkqLF+FlCP5VeRn6srwMfVlehr4ML0O3kJehO15mg7wMIc/gZcAHMZdrrRinVAqce1IG"
        "uRzZR2Qk/N/uYYLGpAwhvzYpQzdNytAtI2Wo3ioOhtBWHAxBAiZMjRX8FvatLLmH64kL06iU2j4c"
        "g5V8EQqG0B0FszoFQ7eagoH14O+YgulCvI0xt5sgJUf2IZMKCoa5mBHGBGJaIy2qHkXhLpIcC0QQ"
        "5oJJRDbGwBCsqFKcafvajW1nYBSzGlaANaSR1Lx8WLYmw9LeBs0USaOH8oHZh22gPcql5AICDIEw"
        "rqRfJHTNCPhNwaVSdEe/7OiXHf2yo1929MuOftnRL7mF4IvQL8V+GtMvrPRrWhBKFN8AvvguPVXz"
        "Lj1M271MjxCXSUkkxGYUKZ57UzZp/KEijF4ktKp4sxfastfkbe6LGBnEPO/rQZ04HPn59FrWZRSd"
        "I674tlCxXrassJIkaPqzBjpgYSz+TdCbue6Fgc2LXbDyUZ44zBX/2wxLJgZY0QSDgpuzt+3/YDbr"
        "2dVO8VtG4D96k3CU3oGFxuJxGCa3PR/mubh44QCw0IvH3mjU689fhbiwJofOTX8E624T9cbel949"
        "4CfNTxY0/K30g50WQA5+TZzvUk3tOVYpcO2rTr3/EpvxX6zov+jvz3/hLfNfZOe/dv5rq/0Xae6/"
        "Sp7YOwsT0/qTUIy3c1wyTwk3TWKj53wTqtJuV117P6o/efD7pngD9lJcv/oxODBR+M8/x3D+y75j"
        "310dxE5ya5z+9Is3aQvXBryCcSwN4Tr/8JNbkNLxkz3nOgo/mwDq+4Ez8QAYzncGLnvlAIidq4vj"
        "09OTS5c4ceL5UTdl5py+F0VfHT9IwrSbgYEyiPHSjlznYBSHIEUYmwUp3JbBQmK+JBkw/ua0kUFD"
        "/ykdxGjm3QCd65t5ieB0ie2pNdtel2LsIkZg3teUSwQrgZWMT+a+OE/of5bxfX/+D+fq3Pl4efxj"
        "gF2n+BWpfefxXfNfw7toiqvvniCy53zwv3gjerTnfH8XfL3zAnrkwLyc1g0fAifu340myX87707f"
        "vD5/87fXH07/9cr9MSCuU/jG+36KmzT8Tf9KO3rwYmfswYQ/jMIxoCz46szzgHvOGx8aOTOJ0wdd"
        "ALAdUAs0Tl3n73fmzrjO1WNDgEoPDCH27gGxgODDcDz8+vHk9VSNr9OQHC78MRBd5bx747z78HHf"
        "+WzMxLFFvXvcA+Ar18EESv+yPzvrfDecYAFWY9H/EEafY2jELlDi1JAe0vfjx871Vye1Vue7G7DB"
        "u2sXZrHX9kz3+MsrMEy4cDgKH2w90KYZHcAtjJPo63P9yO7Gbv2Nbe8S7a8pLIrr7Sfbni+O5svC"
        "uWOZO77MbrDptwanhzPQPbU3JwN5bXsZ51XyJfOKxmmtsLKs8VphWa1gsmzw6ZcjK5qbN0JKmtNl"
        "4mW/WFvR6lwMWtsqbtSqqlWbLhlJvSozcpTCB5eNfrYJoKJNXK88TEo1mt18V9UwrtVfpmHcsGFa"
        "cmVG4rI7+LgLsqpFVj/e0h5Xk5XXDzjTMmnYsihrmZS1nNkW87gPq6pNWa9FXOYRlrWpyoZd1mRG"
        "tXYrV1V7ul4czEtvv02OVHnTJRYg2loAWWIBoi2qMnv2ynVQ5iTrdbDEpmRjm8pkQEo1iGXr0fN6"
        "FWZabmhTmRxoqQqxbG5TmbxEqRYz9rGyTZElNqUa2lTmLRGl4mDd1KZovU1lTK6hTdF6m8o03BBV"
        "mR1WpTrItLyiTdF6myK4sU1RVq9BgluPnterMNNyQ5vKPIZfqsJMyyvbFJX1WiSkuU3RepsipKFN"
        "UV0vDqFNbYplpCnz+kQ0bhHVrx1Lu6lvkdSLU7pUybWYCadsEDrJxFPFd8eUpI9PpjmaTNBm41g/"
        "uCnuXc4mm3JHGBWfWixLIs0jQTqUSmczXfP8Un3OrET6D14cO3jfyb2ms2IIVrDKQTCC3PRl6QQT"
        "pgXKsWdwJXU545RhqrjUnNUOUHmq+eho1ejIlB2BuD4Kx84kHfCf4zSF8Gr5mDnlrhSCw8CU5CrH"
        "snQJdiW3ezq5IIzwHCXBBHWRsDsyJRQyLgsK4S62CmVQR6IN6INV6YParzlQkdUHWVkfBNGqZ0m6"
        "hLuEc27fhULtZ7pzb/9CLheMEqUUwVpTmlMGoS4FHVKFocJGtMFLtHE4T1QvHXdX6prccTF1nL3V"
        "MmfcakO2LcrudjbvlDIBDiJOd57z23P6t54fWON3/jo1kr86+W1JrdQB97GQSq/UB2X1+vAASvq6"
        "Th8Z791/2ic41VIn/UTqPEPaGeQY5aetachlWiKOBccUK0Foxnl1wuEwTjemZ4dPJLFvvrEvvqGM"
        "apT7zCNzEcF2czcRYCNz6vun/B3sgP3Z7biDTyaKZw+lgm25eDbczqfvL3vTpwQnkbn3zUOBPl2s"
        "8PjIGcpWeG8Sb+Al3mx7bWavblr+gzGTE5AkGpuBP73eVrE1HvV4/yQhqOqPf/j2/yAnIeQWoQAA"
    )),
    ("PixelArtistry_Hi3D_03_Your_Mesh_Single_Pass.json", (
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
