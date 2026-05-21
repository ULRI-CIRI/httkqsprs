# Dawson 2021 httkqspr

Building the application

```bash
cd ~/dev/dawson2021-httkqspr
podman build -t httkqspr:latest -f containers/Dockerfile .

# for debugging
podman run --rm --entrypoint bash -it httkqspr:latest
```

Running the application

```bash
cd ~/dev/dawson2021-httkqspr/tmp
podman run --rm --volume="$(pwd):/data" --workdir=/data --cpus=8 --memory=48g httkqspr:latest NewHTTK_April_2026 /data
```
