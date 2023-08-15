!/bin/bash


#echo "Worker Initiated"

#while true; do
#  sleep 3600  # Sleep for 1 hour before checking again (adjust as needed)
#done


echo "Worker Initiated"

echo "Starting WebUI API"
#python /stable-diffusion-webui/webui.py --ckpt /model.safetensors --lowram --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-download-sd-model &
python /stable-diffusion-webui/webui.py --skip-python-version-check --skip-torch-cuda-test --skip-install --ckpt /model.safetensors --medvram --opt-sdp-attention --disable-safe-unpickle --port 3000 --api --nowebui --skip-version-check  --no-hashing --no-download-sd-model &

echo "Starting RunPod Handler"
python -u /rp_handler.py
