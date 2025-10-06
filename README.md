<div align="center">

# asdf-odin [![Build](https://github.com/hisamafahri/asdf-odin/actions/workflows/build.yml/badge.svg)](https://github.com/hisamafahri/asdf-odin/actions/workflows/build.yml) [![Lint](https://github.com/hisamafahri/asdf-odin/actions/workflows/lint.yml/badge.svg)](https://github.com/hisamafahri/asdf-odin/actions/workflows/lint.yml)

[odin](https://github.com/hisamafahri/asdf-odin) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Install](#install)
- [Contributing](#contributing)
- [License](#license)

# Install

Plugin:

```shell
asdf plugin add odin https://github.com/hisamafahri/asdf-odin.git
```

odin:

```shell
# Show all installable versions
asdf list all odin

# Install specific version
asdf install odin latest

# Set a version globally (on your ~/.tool-versions file)
asdf global odin latest

# Now odin commands are available
odin version
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/hisamafahri/asdf-odin/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Hisam Fahri](https://github.com/hisamafahri/)
