# Use RunPod's base PyTorch image
FROM runpod/pytorch:3.10-2.0.0-117

# Use bash shell with pipefail option
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set the working directory
WORKDIR /

# Update and upgrade the system packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
        fonts-dejavu-core rsync nano git jq moreutils aria2 wget mc libgoogle-perftools-dev procps && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118   

# Clone the specific version of AUTOMATIC1111 Stable Diffusion WebUI
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard 82a973c04367123ae98bd9abdf80d9eda9b910e2

# Copy the script into the container
COPY builder/check_and_download.sh /usr/local/bin/check_and_download.sh

# Make the script executable
RUN chmod +x /usr/local/bin/check_and_download.sh

# Run the script
RUN /usr/local/bin/check_and_download.sh   

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN pip install --upgrade pip && \
    pip install --upgrade -r /requirements.txt --no-cache-dir && \
    rm /requirements.txt

# Set up the model
RUN cd /stable-diffusion-webui && \
    pip install --upgrade pip && \
    pip install --upgrade -r requirements.txt --no-cache-dir

# Clone the ControlNet extension into the WebUI's extensions directory
RUN git clone https://github.com/Mikubill/sd-webui-controlnet.git /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    cd /stable-diffusion-webui/extensions/sd-webui-controlnet && \
    # Checkout the specific commit
    git reset --hard 56cec5b2958edf3b1807b7e7b2b1b5186dbd2f81 && \
    # Install ControlNet's Python dependencies
    pip install --upgrade pip && \
    pip install --upgrade -r /stable-diffusion-webui/extensions/sd-webui-controlnet/requirements.txt --no-cache-dir

# Clone the regional prompter into the WebUI's extensions directory
RUN git clone https://github.com/hako-mikan/sd-webui-regional-prompter.git /stable-diffusion-webui/extensions/sd-webui-regional-prompter && \
    cd /stable-diffusion-webui/extensions/sd-webui-regional-prompter && \
    # Checkout the specific commit
    git reset --hard 4802faca6bcc40c4d1033920e8ad9fd7542eca79   

RUN mkdir -p /stable-diffusion-webui/models/ControlNet
RUN mkdir -p /stable-diffusion-webui/models/Lora

# Download the IP-Adapter FaceID model and place it in the ControlNet models directory
RUN wget -q -O /stable-diffusion-webui//models/ControlNet/ip-adapter-plus-face_sdxl_vit-h.safetensors \
https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors

RUN wget -q -O /stable-diffusion-webui//models/ControlNet/ip-adapter_sdxl.safetensors \
https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl.safetensors

RUN wget -q -O /stable-diffusion-webui//models/ControlNet/ip-adapter_sdxl_vit-h.safetensors \
https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors

RUN wget -q -O /stable-diffusion-webui//models/ControlNet/ip-adapter_xl.pth \
https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/ip-adapter_xl.pth

RUN wget -q -O /stable-diffusion-webui//models/ControlNet/ip-adapter-faceid_sdxl.bin \
https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl.bin

RUN wget -q -O /stable-diffusion-webui//models/Lora/ip-adapter-faceid_sdxl_lora.safetensors \
https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl_lora.safetensors

# Download the Openpose model and place it in the ControlNet models directory
RUN wget -q -O /stable-diffusion-webui//models/ControlNet/controlnet-openpose-sdxl-1.0.safetensors \
https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model.safetensors

RUN wget -q -O /stable-diffusion-webui//models/ControlNet/controlnet-openpose-sdxl-1.0_twins.safetensors \
https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0/resolve/main/diffusion_pytorch_model_twins.safetensors

# Launch the WebUI to finalize setup (this step installs any remaining dependencies)
RUN python /stable-diffusion-webui/launch.py --model /stable-diffusion-webui/model.safetensors --exit --skip-torch-cuda-test --xformers --no-half --reinstall-xformers

# RUN pip install --upgrade torchdynamo
RUN pip install protobuf==3.20.3
RUN pip install xformers==0.0.27.post2

# Copy additional resources
COPY embeddings /stable-diffusion-webui/embeddings
COPY loras /stable-diffusion-webui/models/Lora
COPY characters /characters
COPY src/base64_encoder.py /base64_encoder.py
ADD src . 

# Download remote_syslog2
RUN wget https://github.com/papertrail/remote_syslog2/releases/download/v0.20/remote_syslog_linux_amd64.tar.gz && \
    tar xzf ./remote_syslog*.tar.gz && \
    cp ./remote_syslog/remote_syslog /usr/local/bin/ && \
    rm -r ./remote_syslog_linux_amd64.tar.gz ./remote_syslog

# Create a config file for remote_syslog
RUN echo "files:" >> /etc/log_files.yml && \
    echo "  - /var/log/runpod_handler.log" >> /etc/log_files.yml && \
    echo "destination:" >> /etc/log_files.yml && \
    echo "  host: logs.papertrailapp.com" >> /etc/log_files.yml && \
    echo "  port: 27472" >> /etc/log_files.yml && \
    echo "  protocol: tls" >> /etc/log_files.yml

# Set up Papertrail (logging)
COPY builder/papertrail.sh /papertrail.sh    
RUN chmod +x /papertrail.sh

# Cleanup and final setup
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Set permissions and specify the command to run
RUN chmod +x /start.sh
CMD /start.sh
