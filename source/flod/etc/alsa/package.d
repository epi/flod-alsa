module flod.etc.alsa;

import deimos.alsa.pcm;
import flod.meta : NonCopyable;
import flod.traits : sink, Method;
import flod.pipeline;

@sink!ubyte(Method.push)
private struct AlsaPcm(alias Context, A...) {
	mixin NonCopyable;
	mixin Context!A;

	private snd_pcm_t* hpcm;
	private int bytesPerSample;

	this(uint channels, uint samplesPerSec, uint bitsPerSample)
	{
		import std.string : toStringz;
		int err;
		if ((err = snd_pcm_open(&hpcm, "default".toStringz(), snd_pcm_stream_t.PLAYBACK, 0)) < 0)
			throw new Exception("Cannot open default audio device");
		setParams(channels, samplesPerSec, bitsPerSample);
		bytesPerSample = bitsPerSample / 8 * channels;
	}

	~this()
	{
		close();
	}

	private void setParams(uint channels, uint samplesPerSec, uint bitsPerSample)
	{
		int err;
		if ((err = snd_pcm_set_params(
			hpcm, bitsPerSample == 8 ? snd_pcm_format_t.U8 : snd_pcm_format_t.S16_LE,
			snd_pcm_access_t.RW_INTERLEAVED,
			channels, samplesPerSec, 1, 100000)) < 0) {
			close();
			throw new Exception("Cannot set audio device params");
		}
	}

	private void close()
	{
		if (hpcm is null)
			return;
		snd_pcm_close(hpcm);
		hpcm = null;
	}

	size_t push(const(ubyte)[] buf)
	{
		snd_pcm_sframes_t frames = snd_pcm_writei(hpcm, buf.ptr, buf.length / bytesPerSample);
		if (frames < 0) {
			frames = snd_pcm_recover(hpcm, cast(int) frames, 0);
			if (frames < 0)
				throw new Exception("snd_pcm_writei failed");
		}
		return buf.length;
	}
}

auto playPcm(S, Args...)(auto ref S schema, auto ref Args args)
	if (isSchema!S)
{
	return schema.pipe!AlsaPcm(args);
}

unittest {
	// play 1 second of 1 kHz sine wave
	import std.math : sin, PI;
	import std.range : iota, cycle, take, array;
	import std.algorithm : map;
	auto buf = iota(8).map!(i => cast(ubyte) (sin(PI * i / 4.0) * 127 + 128))
		.cycle.take(8000).array();
	buf.playPcm(1, 8000, 8);
}
