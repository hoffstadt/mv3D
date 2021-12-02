#pragma once

#include <chrono>
#include "mvSandbox.h"

class mvTimer
{

public:

	mvTimer();

	f32 mark();
	f32 peek();
	f32 now();
	
private:

	std::chrono::steady_clock::time_point m_start;
	std::chrono::steady_clock::time_point m_last;
};