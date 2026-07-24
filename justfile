[private]
list:
    @just --list --unsorted

# 📥 install
install:
  rv sync

# 🧹 Lint code
lint:
  uvx --from air-formatter air format . --check

# ✨ Format code
format:
  uvx --from air-formatter air format .

# 📚 Document package
document:
  R -e "devtools::document('httkqsprs')"

# 📦 Build package
build:
  R -e "devtools::build('httkqsprs')"
