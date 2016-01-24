module flod.etc.alsa;

import deimos.alsa.pcm;

struct AlsaPcm {

	this(uint channels, uint samplesPerSec, uint bitsPerSample)
	{
		import std.string : toStringz;
		int err;
		if ((err = snd_pcm_open(&hpcm, "default".toStringz(), snd_pcm_stream_t.PLAYBACK, 0)) < 0)
			throw new Exception("Cannot open default audio device");
		if ((err = snd_pcm_set_params(
			hpcm, bitsPerSample == 8 ? snd_pcm_format_t.U8 : snd_pcm_format_t.S16_LE,
			snd_pcm_access_t.RW_INTERLEAVED,
			channels, samplesPerSec, 1, 50000)) < 0) {
			close();
			throw new Exception("Cannot set audio device params");
		}
		bytesPerSample = bitsPerSample / 8 * channels;
	}

	~this()
	{
		close();
	}

	void close()
	{
		if (hpcm is null)
			return;
		snd_pcm_close(hpcm);
		hpcm = null;
	}

	void push(const(ubyte)[] buf)
	{
		snd_pcm_sframes_t frames = snd_pcm_writei(hpcm, buf.ptr, buf.length / bytesPerSample);
		if (frames < 0) {
			frames = snd_pcm_recover(hpcm, cast(int) frames, 0);
			if (frames < 0)
				throw new Exception("snd_pcm_writei failed");
		}
	}

private:
	snd_pcm_t* hpcm;
	int bytesPerSample;
}

unittest
{
	// play 1 second of 1 kHz sine wave
	import std.math : sin, PI;
	import std.range : iota, cycle, take, array;
	import std.algorithm : map;
	auto pcm = AlsaPcm(1, 8000, 8);
	auto buf = iota(8).map!(i => cast(ubyte) (sin(PI * i / 4.0) * 127 + 128))
		.cycle.take(8000).array();
	pcm.push(buf);
}
