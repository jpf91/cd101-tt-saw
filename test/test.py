# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from bitarray import bitarray
from collections import namedtuple

SPIConfig = namedtuple("SPIConfig", ["adsr_ai", "adsr_di", "adsr_s", "adsr_ri", "osc_count", "filter_a", "filter_b"])

def bitarray_reverse(arr):
    arr.reverse()
    return arr

def int2bits(n, nbits):
    return f"{n & ((1 << nbits) - 1):0{nbits}b}"

class CD101SPI:
    def __init__(self, dut):
        self.nss = dut.uio_in[0]
        self.mosi = dut.uio_in[1]
        self.sck = dut.uio_in[3]
        self.sysclk = dut.clk

    async def __write(self, data, finalDelay = 1, initialDelay = 1):
        # NSS low
        self.nss.value = 0

        # SPI is 1 MHz clock
        await ClockCycles(self.sysclk, initialDelay * 24)

        for bval in data:
            self.mosi.value = bval
            await ClockCycles(self.sysclk, 12)
            self.sck.value = 1
            await ClockCycles(self.sysclk, 12)
            self.sck.value = 0

        await ClockCycles(self.sysclk, finalDelay * 24)
        self.nss.value = 1

    async def set_trigger(self, on):
        if (on):
            await self.__write(bitarray('1'))
        else:
            await self.__write(bitarray('0'))

    async def set_config(self, trig, cfg):
        data = bitarray()
        if (trig):
            data.append(1)
        else:
            data.append(0)
        
        data.extend(bitarray_reverse(bitarray(int2bits(cfg.adsr_ai, 8))))
        data.extend(bitarray_reverse(bitarray(int2bits(cfg.adsr_di, 8))))
        data.extend(bitarray_reverse(bitarray(int2bits(cfg.adsr_s, 8))))
        data.extend(bitarray_reverse(bitarray(int2bits(cfg.adsr_ri, 8))))
        data.extend(bitarray_reverse(bitarray(int2bits(cfg.osc_count, 12))))
        data.extend(bitarray_reverse(bitarray(int2bits(cfg.filter_a, 8))))
        data.extend(bitarray_reverse(bitarray(int2bits(cfg.filter_b, 8))))

        await self.__write(data)

import numpy as np
from scipy.signal import butter, lfilter
import wave
import sys

class AudioFilter:
    def __init__(self):
        order = 5
        nyquist = 0.5 * 24000000
        high = 20000 / nyquist
        self.b, self.a = butter(order, high, btype='low', analog=False)
        self.z = np.zeros(self.b.size - 1)

        self.wf = wave.open("output.wav", 'wb')
        self.rwf = wave.open("golden.wav", 'rb')
        self.wf.setnchannels(1)
        self.wf.setsampwidth(2)
        self.wf.setframerate(48000)

    # Filter by chunks of 2000 samples (float)
    def __filter(self, data):
        y, self.z = lfilter(self.b, self.a, data, zi = self.z)
        return y

    # Filter by chunks of 2000 samples (float)
    def process(self, data):
        filtered = self.__filter(data)
        resampled = [filtered[249], filtered[749], filtered[1249], filtered[1749]]

        # Convert to int16
        resampled = np.clip(resampled, 0, 1)
        resampled_i16 = (resampled * np.iinfo(np.int16).max).astype(np.int16)

        # Save to wav
        self.wf.writeframes(resampled_i16.tobytes())

        # Compare to reference
        refdata = self.rwf.readframes(4)
        #assert resampled_i16.tobytes() == refdata, "Data does not match reference"

    def finish(self):
        self.wf.close()

async def collect_output(dut):
    af = AudioFilter()
    
    buf = np.zeros(2000)
    # 1 second of data
    for i in range(1, 24000001):
        sample = dut.uo_out[7].value.integer
        if (sample != 1 and sample != 0):
            sample = 0
        buf[i % 2000] = sample
        if (i % 2000 == 1999):
            af.process(buf)
        await ClockCycles(dut.clk, 1)

    af.finish()

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock to 24 MHz
    clock = Clock(dut.clk, 41.666, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 1
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.uio_in[0].value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 0

    # Reset needs to be quite long, as its synchronous on slow clk
    await ClockCycles(dut.clk, int(0.003125 * 24000000))
    dut.rst_n.value = 1

    dut._log.info("Testing Audio Generation")
    spi = CD101SPI(dut)

    config = SPIConfig(10, -1, 145, -1, 53, 102, 153)
    await spi.set_config(False, config)
    await ClockCycles(dut.clk, 10)
    
    receiver = cocotb.start_soon(collect_output(dut))
    await ClockCycles(dut.clk, 10)
    await spi.set_trigger(True)
    # Wait 0.5s
    await ClockCycles(dut.clk, 12000000)
    await spi.set_trigger(False)

    await receiver
