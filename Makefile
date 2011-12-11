# nss Makefile

SOURCE_PATH = ${CURDIR}
INSTALL_PATH = /usr/bin

SERVER_DIR = .nss-server-template

install:
	cp "${SOURCE_PATH}/nss" "${INSTALL_PATH}/nss"
	chown root:root "${INSTALL_PATH}/nss"
	chmod 755 "${INSTALL_PATH}/nss"
	mkdir "${INSTALL_PATH}/${SERVER_DIR}"
	cd "${SOURCE_PATH}/server"; tar cf - . | (cd "${INSTALL_PATH}/${SERVER_DIR}" && tar xf -); cd "${SOURCE_PATH}"
	chown -R root:root  "${INSTALL_PATH}/${SERVER_DIR}"
	chmod -R 755 "${INSTALL_PATH}/${SERVER_DIR}"
	test -d "/etc/bash_completion.d" && \
		cp "${SOURCE_PATH}/completion.sh" "/etc/bash_completion.d/nss"

uninstall:
	rm -f "${INSTALL_PATH}/nss"
	rm -rf "${INSTALL_PATH}/${SERVER_DIR}"
	test -d "/etc/bash_completion.d" && \
		rm -f "/etc/bash_completion.d/nss"

reinstall: uninstall install

# End of file Makefile
