/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

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
  bool valid;

public:
  LinuxIPC(int id = 1234) : shmid(-1), sharedData(nullptr), key(-1), valid(false) {
    key = ftok(".", id);
    if (key == -1) {
      std::cerr << "LinuxIPC: ftok failed" << std::endl;
      return;
    }

    shmid = shmget(key, sizeof(IPCData), 0600 | IPC_CREAT);
    if (shmid == -1) {
      std::cerr << "LinuxIPC: shmget failed" << std::endl;
      return;
    }

    sharedData = (IPCData *)shmat(shmid, (void *)0, 0);
    if (sharedData == (void *)-1) {
      std::cerr << "LinuxIPC: shmat failed" << std::endl;
      sharedData = nullptr;
      return;
    }

    // Only initialize if we created it
    struct shmid_ds buf;
    shmctl(shmid, IPC_STAT, &buf);
    if (buf.shm_nattch <= 1) {
      std::memset(sharedData, 0, sizeof(IPCData));
      sharedData->speed = 1.0f;
      sharedData->intensity = 1.0f;
    }

    valid = true;
  }

  ~LinuxIPC() {
    if (sharedData && sharedData != (void *)-1) {
      shmdt(sharedData);
    }
    if (shmid != -1) {
      shmctl(shmid, IPC_RMID, NULL);
    }
  }

  bool isValid() const { return valid; }

  void updateShader(const std::string &shaderName) {
    if (!valid || !sharedData)
      return;
    std::strncpy(sharedData->currentShader, shaderName.c_str(), 255);
    sharedData->updateNeeded = true;
  }

  void updateSettings(float speed, float intensity) {
    if (!valid || !sharedData)
      return;
    sharedData->speed = speed;
    sharedData->intensity = intensity;
    sharedData->updateNeeded = true;
  }

  IPCData *getData() { return valid ? sharedData : nullptr; }

  static void cleanup(int id = 1234) {
    key_t k = ftok(".", id);
    if (k == -1)
      return;
    int s = shmget(k, sizeof(IPCData), 0600);
    if (s != -1)
      shmctl(s, IPC_RMID, NULL);
  }
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy

#endif // LINUX_IPC_H
