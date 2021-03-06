**Protox privacy policy**

1. Protox uses libtoxcore (https://github.com/TokTok/c-toxcore) to provide instant messaging and audio/video conference functionality.

2. Protox stores your Tox profile only on your device, it's not stored on any other server.

    2.1 If someone gains an access to the Tox profile stored on your device, they can claim your identity on Tox. If you have selected a password for your Tox profile, the Tox profile would be stored encrypted with your password, which would mitigate the issue of someone claiming your identity on Tox by stealing the Tox profile file, assuming the attacker can't easily guess the password.

    2.2 As a consequence of storing the profile only on the device, you can't restore your Tox profile if you lose it.
    
3. Protox stores the message and audio/video call logs only on your device, they are not stored on any other server.

4. All the data sent over the network, including messages and audio/video calls, are sent encrypted in such a way that only the intended recepient can decrypt them.

5. All the data sent over the network, including messages and audio/video calls, are sent directly to the intended recepient without use of any central server, with a few exceptions as follows.

    5.1 Tox tries to establish a direct, peer-to-peer, connection with the recepients. In some cases it's not possible due to the network restrictions (restrictive NATs), in which case libtoxcore uses a relay node to relay all your conversations with a recepient. Note that by №4 the relay node can't decrypt contents of messages and audio/video calls, as the relay node is not the intended recepient of those.

    5.2 If you have TCP mode enabled, your traffic is rounter though a relay node. Note that by №4 the relay node can't decrypt contents of messages and audio/video calls, as the relay node is not the intended recepient of those.

    5.3 If you have specified a HTTP or SOCKS5 proxy, libtoxcore would relay the traffic using that proxy. Note that by №4 the proxy can't decrypt contents of messages and audio/video calls, as the proxy is not the intended recepient of those.

6. libtoxcore doesn't route DNS traffic though a proxy.

7. In order to be able to discover other Tox users and be discovered by them, libtoxcore uses DHT. Every Tox client is a DHT node. The data that is stored in DHT is 1) your temporary DHT public key, which can't be used to identify you as it's generated randomly and changes every time you restart Protox, and 2) your IP address.

    7.1 The implication of this is that everyone can traverse the DHT and find IP addresses of all Tox users, including you. Everyone can tell that someone on your IP address is running Tox. Those IP addresses might be the actual addresses of Tox users, or addresses of proxies if the Tox users used a proxy. If you don't want to let anyone know that you are running Tox on your IP address, you should use a proxy.

    7.2 Tox is designed to prevent any user you have not authorized (added as a friend) from finding the association of your Tox Id and IP based on DHT data.

8. To connect to the DHT Protox utilizes a list of bootstrap nodes maintained by Tox Project at https://nodes.tox.chat/.

