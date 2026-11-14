#ifndef RUNNER_SECURE_STORE_H_
#define RUNNER_SECURE_STORE_H_
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <memory>
void HandleSecureCall(const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
#endif
