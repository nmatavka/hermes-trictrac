import { Socket } from "phoenix";

const socket = new Socket("/socket", {
  params: { token: window.userToken },
  timeout: 120000
});

socket.connect();

export default socket;
