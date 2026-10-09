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

# 🧪 Test package
test:
  Rscript -e "devtools::test(pkg='httkqsprs')"

# 📚 Document package
document:
  R -e "devtools::document(pkg='httkqsprs')"

# 🔍 Check package build
check:
  R -e "devtools::check(pkg='httkqsprs')"

# 📦 Build package
build:
  R -e "devtools::build(pkg='httkqsprs')"
