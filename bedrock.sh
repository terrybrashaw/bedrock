#!/bin/bash

function echo_error() {
    echo -e "\\e[31mError\\e[39m: $*"
    return 0
}

function echo_success() {
    echo -e "\\e[32mSuccess\\e[39m: $*"
    return 0
}

function echo_warning() {
    echo -e "\\e[33mWarning\\e[39m: $*"
    return 0
}

# Instead of just putting comments in the code, write them to stdout.
function echo_comment() {
    echo -e "\\e[1m# $*\\e[0m"
    return 0
}

function echo_usage() {
    echo "USAGE:"
    echo "    bedrock.sh --void --amd"
    echo "    bedrock.sh --void --nvidia"
    return 0
}

CLAYMORE_VERSION="claymore-11.2"
linux_distribution=""
gpu_vendor=""
is_args_ok=true

if [[ "$LOGNAME" == "root" ]]; then
    echo_error "Running as root"
    is_args_ok=false
else
    # Running an empty command to get root privileges for the rest of the script
    sudo sh -c ""
fi

for arg in "$@"; do
    case "$arg" in
        --nvidia|--amd)
            if [[ "$gpu_vendor" == "" ]]; then
                gpu_vendor="$arg"
            else
                echo_error "GPU vendor already set; ${arg} conflicts with ${gpu_vendor}"
                is_args_ok=false
            fi
            ;;
        --void)
            if [[ "$linux_distribution" == "" ]]; then
                linux_distribution="$arg"
            else
                echo_error "Distribution already set; ${arg} conflicts with ${linux_distribution}"
                is_args_ok=false
            fi
            ;;
        *)
            echo_warning "Unused argument \"${arg}\""
            ;;
    esac
done

if [[ "$linux_distribution" == "" ]]; then
    echo_error "No distribution specified."
    is_args_ok=false
fi

if [[ "$gpu_vendor" == "" ]]; then
    echo_error "No GPU specified."
    is_args_ok=false
fi

if [[ $is_args_ok == false ]]; then
    echo ""
    echo_usage
    exit 1
fi

if [[ "$linux_distribution" == "--void" ]]; then
    echo
    echo_comment "Update the system"
    sudo xbps-install --sync --update --yes 

    # Do this before installing anything else, because accurate time is kind of important.
    echo
    echo_comment "Setup the NTP daemon"
    sudo xbps-install --sync --yes chrony
    sudo ln --force --verbose --symbolic /etc/sv/chronyd/ /var/service/
    sudo sv start chronyd

    echo
    echo_comment "Setup the SSH daemon"
    sudo ln --force --verbose --symbolic /etc/sv/sshd/ /var/service/
    sudo sv start sshd

    echo
    echo_comment "Install/update general-purpose applications and dependencies"
    sudo xbps-install --sync --yes \
        pkg-config \
        fish-shell \
        neovim \
        tmux \
        git \
        ripgrep \
        fzf \
        fd \
        ranger \
        exa \
        curl \
        libcurl \
        htop \
        glances \
        neofetch \
        gcc \
        make \
        cmake \
        xz \
        ntfs-3g \
        zip \
        unzip

    echo
    echo_comment "Install/update GPU drivers and settings (${gpu_vendor})"
    case "$gpu_vendor" in
        --nvidia)
            sudo xbps-install --sync --yes \
                void-repo-nonfree \
                nvidia \
                nvidia-opencl
            ;;
        --amd)
            ;;
    esac

    echo
    echo_comment "Give ${LOGNAME} the privilege to reboot the computer"
    sudo sh -c "echo \"${LOGNAME} ALL=NOPASSWD: /sbin/reboot\" > /etc/sudoers.d/${LOGNAME}_reboot"
    # Print the contents of the file, just to show some kind of feedback
    sudo cat /etc/sudoers.d/"${LOGNAME}"_reboot

    echo
    echo_comment "Create symbolic links to libs that Claymore needs"
    sudo ln --force --verbose --symbolic /lib/libssl.so /lib/libssl.so.1.0.0
    sudo ln --force --verbose --symbolic /lib/libcrypto.so /lib/libcrypto.so.1.0.0

    echo
    echo_comment "Install Claymore"
    cp --force --recursive ./${CLAYMORE_VERSION} ~/
    ln --force --verbose --symbolic ~/${CLAYMORE_VERSION} ~/claymore

    # Install the Claymore runit service
    sudo rm --recursive --force /etc/sv/claymore
    sudo cp --recursive --force ./sv/claymore /etc/sv/
    sudo chmod --recursive a+rx /etc/sv/claymore

    # Specify this user as the miner for Claymore.
    echo "export MINER=\"${LOGNAME}\"" > temp.sh
    sudo mv --force temp.sh /etc/sv/claymore/miner.sh

    # Enable the Claymore runit service
    sudo ln --force --verbose --symbolic /etc/sv/claymore /var/service 
fi

echo_success "Done"
echo "Don't forget!!! Add ETHER_WALLET to ~/.bashrc"

exit 0

