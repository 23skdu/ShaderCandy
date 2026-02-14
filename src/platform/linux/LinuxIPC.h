#ifndef LINUX_IPC_H
#define LINUX_IPC_H

#include <cstring>
#include <iostream>
#include <string>
#include <sys/ipc.h>
#include <sys/shm.h>

namespace ShaderCandy {
namespace Platform {
namespace Linux {

struct IPCData {
  char currentShader[256];
  float speed;
  float intensity;
  bool quit;
  bool updateNeeded;
};

class LinuxIPC {
private:
  int shmid;
  IPCData *sharedData;
  key_t key;

public:
  LinuxIPC(int id = 1234) {
    key = ftok(".", id);
    shmid = shmget(key, sizeof(IPCData), 0666 | IPC_CREAT);
    sharedData = (IPCData *)shmat(shmid, (void *)0, 0);

    // Only initialize if we created it
    struct shmid_ds buf;
    shmctl(shmid, IPC_STAT, &buf);
    if (buf.shm_nattch <= 1) {
      std::memset(sharedData, 0, sizeof(IPCData));
      sharedData->speed = 1.0f;
      sharedData->intensity = 1.0f;
    }
  }

  ~LinuxIPC() { shmdt(sharedData); }

  void updateShader(const std::string &shaderName) {
    std::strncpy(sharedData->currentShader, shaderName.c_str(), 255);
    sharedData->updateNeeded = true;
  }

  void updateSettings(float speed, float intensity) {
    sharedData->speed = speed;
    sharedData->intensity = intensity;
    sharedData->updateNeeded = true;
  }

  IPCData *getData() { return sharedData; }

  static void cleanup(int id = 1234) {
    key_t k = ftok(".", id);
    int s = shmget(k, sizeof(IPCData), 0666);
    shmctl(s, IPC_RMID, NULL);
  }
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy

#endif // LINUX_IPC_H
