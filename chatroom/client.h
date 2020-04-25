#ifndef CLIENT_H
#define CLIENT_H
 
#include "common.h" 
using namespace std;

class Client {
 
public:
    Client() {
        serverAddr.sin_family = PF_INET;
        serverAddr.sin_port = htons(SERVER_PORT);
        serverAddr.sin_addr.s_addr = inet_addr(SERVER_IP);
        sock = 0;
        pid = 0;
        isClientwork = true;
        epfd = 0;
    }

    void Connect() {
        sock = socket(PF_INET, SOCK_STREAM, 0);
        if(sock < 0) {
            perror("sock");
            exit(-1); 
        }
        if(connect(sock, (struct sockaddr *)&serverAddr, sizeof(serverAddr)) < 0) {
            perror("connect");
            exit(-1);
        }
        if(pipe(pipe_fd) < 0) {
            perror("pipe");
            exit(-1);
        }
        epfd = epoll_create(EPOLL_SIZE);
        if(epfd < 0) {
            perror("epfd");
            exit(-1); 
        }
        addfd(epfd, sock, true);
        addfd(epfd, pipe_fd[0], true);
    }

    void Close() {
        if(pid) {
            close(pipe_fd[0]);
            close(sock);
        } else {
            close(pipe_fd[1]);
        }
    }

    void Start() {
        static struct epoll_event events[2];
        Connect();
        pid = fork();
        if(pid < 0) {
            perror("fork");
            close(sock);
            exit(-1);
        } else if(pid == 0) {
            close(pipe_fd[0]); 
            cout << "You can input [exit] to exit" << endl;
            while(isClientwork) {
                memset(msg.content, 0, sizeof(msg.content));
                fgets(msg.content, BUF_SIZE, stdin);
                if(strncasecmp(msg.content, EXIT, strlen(EXIT)) == 0){
                    isClientwork = 0;
                } else {
                    memset(send_buf, 0, BUF_SIZE);
                    memcpy(send_buf, &msg, sizeof(msg));
                    if(write(pipe_fd[1], send_buf, sizeof(send_buf)) < 0) { 
                        perror("fork");
                        exit(-1);
                    }
                }
            }
        } else { 
            close(pipe_fd[1]); 
            while(isClientwork) {
                int epoll_events_count = epoll_wait(epfd, events, 2, -1);
                for(int i = 0; i < epoll_events_count ; ++i) {
                memset(recv_buf, 0, sizeof(recv_buf));
                if(events[i].data.fd == sock) {
                    int ret = recv(sock, recv_buf, BUF_SIZE, 0);
                    memset(&msg, 0, sizeof(msg));
                    memcpy(&msg, recv_buf, sizeof(msg));
                    if(ret == 0) {
                        cout << "Server closed connection: " << sock << endl;
                        close(sock);
                        isClientwork = 0;
                    } else {
                        cout << msg.content << endl;
                    }
                } else { 
                    int ret = read(events[i].data.fd, recv_buf, BUF_SIZE);
                    if(ret == 0)
                        isClientwork = 0;
                    else {
                        send(sock, recv_buf, sizeof(recv_buf), 0);
                    }
                }
            }
        }
    }
    Close();
}
 
private:
    int sock;
    int pid;
    int epfd;
    int pipe_fd[2];
    bool isClientwork;
    Msg msg;
    char send_buf[BUF_SIZE];
    char recv_buf[BUF_SIZE];
    struct sockaddr_in serverAddr;
};

#endif
