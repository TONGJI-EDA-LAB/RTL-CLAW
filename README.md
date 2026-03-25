# RTL-CLAW: An AI-Agent-Driven Framework for Automated IC Design Flow

This project is primarily aimed at showcasing an EDA toolchain based on the OpenClaw framework, in which our own research work is also demonstrated. The project will be continuously updated to support the integration of more of our research outcomes, open-source tools, and commercial tools into the toolchain in the form of additional plugins.

If you have any questions, please feel free to submit an issue to help us improve!

1st. This image is built locally based on the official OpenClaw image. Please follow the OpenClaw official repository to build `openclaw:local` locally.

2nd. The image build command is:  
`docker build -t rtl-claw:latest-dev .`  

*Note: Some features are not yet publicly available as the related research has not been published.*

3rd. Initialize to generate minimal config:

```bash
docker compose run --rm rtl-claw-cli onboard \
    --reset \
    --non-interactive \
    --accept-risk \
    --flow Manual \
    --gateway-bind lan \
    --skip-channels \
    --skip-daemon \
    --skip-search \
    --skip-skills
```

4th. Start container services:

```bash
mkdir .openclaw/ && mkdir workspace
docker compose up -d rtl-claw-gateway
```

5