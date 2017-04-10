/* reSID interface
 *
 * much of the code here is from GOATTRACKER, (c) Cadaver
 */
#define PALCLOCKRATE 985248
#define NTSCCLOCKRATE 1022727

#define NUMSIDREGS 0x19
#define SIDWRITEDELAY 9 // lda $xxxx,x 4 cycles, sta $d400,x 5 cycles
#define SIDWAVEDELAY 4 // and $xxxx,x 4 cycles extra

#include <stdlib.h>
#include <resid/sid.h>
#include <resid-fp/sidfp.h>
#include <assert.h>
#include <stdio.h>

extern "C" {
	typedef struct
	{
		float distortionrate;
		float distortionpoint;
		float distortioncfthreshold;
		float type3baseresistance;
		float type3offset;
		float type3steepness;
		float type3minimumfetresistance;
		float type4k;
		float type4b;
		float voicenonlinearity;
	} FILTERPARAMS;

	int clockrate;
	int samplerate;
	unsigned char sidreg[2][NUMSIDREGS];
	const unsigned char sidorder[] = {
        0x0e,0x0f,0x14,0x13,0x10,0x11,0x12,
        0x07,0x08,0x0d,0x0c,0x09,0x0a,0x0b,
        0x00,0x01,0x06,0x05,0x02,0x03,0x04,
        0x16,0x17,0x18,0x15
	};
	SID *sid= 0;
	SIDFP *sidfp[2] = { 0, 0 };
	int residdelay = 0;
	int usestereo = 0;
	int usefp = 1;

	void sid_close() {
		if(sid) delete sid;
		if(sidfp[0]) delete sidfp[0];
		if(sidfp[1]) delete sidfp[1];
	}

	void sid_set_fp_params(SIDFP *sidfp, const FILTERPARAMS *fparams, int speed, unsigned m, unsigned ntsc, unsigned interpolate, unsigned customclockrate) {
		switch(interpolate)
		{
		case 0:
			sidfp->set_sampling_parameters(clockrate, SAMPLE_INTERPOLATE, speed);
			break;
		default:
			sidfp->set_sampling_parameters(clockrate, SAMPLE_RESAMPLE_INTERPOLATE, speed);
			break;
		}
		sidfp->reset();
		if (m == 1) {
			sidfp->set_chip_model(MOS8580);
		}
		else {
			sidfp->set_chip_model(MOS6581);
		}
		sidfp->get_filter().set_distortion_properties(
			fparams->distortionrate,
			fparams->distortionpoint,
			fparams->distortioncfthreshold);
		sidfp->get_filter().set_type3_properties(
			fparams->type3baseresistance,
			fparams->type3offset,
			fparams->type3steepness,
			fparams->type3minimumfetresistance);
		sidfp->get_filter().set_type4_properties(
			fparams->type4k,
			fparams->type4b);
		sidfp->set_voice_nonlinearity(
			fparams->voicenonlinearity);
		sidfp->enable_filter(true);

	}
	
	void sid_init(const FILTERPARAMS **fparams, int speed, unsigned short *m, unsigned ntsc, unsigned interpolate, unsigned customclockrate, int stereo)
	{
		int c;

		usestereo = stereo;
		
		if (ntsc) clockrate = NTSCCLOCKRATE;
		else clockrate = PALCLOCKRATE;
	
		if (customclockrate)
			clockrate = customclockrate;
	
		samplerate = speed;
	
		if (!sidfp[0]) sidfp[0] = new SIDFP();
		if (!sidfp[1]) sidfp[1] = new SIDFP();
		if (!sid) sid = new SID();

		for (c = 0; c < NUMSIDREGS; c++) {
			sidreg[0][c] = 0x00;
			sidreg[1][c] = 0x00;
		}

		if(usefp) {
			sid_set_fp_params(sidfp[0], fparams[0], speed, m[0], ntsc, interpolate, customclockrate);
			sid_set_fp_params(sidfp[1], fparams[1], speed, m[1], ntsc, interpolate, customclockrate);
		}
		else {
			/*
			switch(interpolate)
			{
			case 0:
				sid->set_sampling_parameters(clockrate, SAMPLE_FAST, speed, 20000);
				break;
			default:
				sid->set_sampling_parameters(clockrate, SAMPLE_INTERPOLATE, speed, 20000);
				break;
			}
			sid->reset();
			if (m == 1) {
				sid->set_chip_model(MOS8580);
			}
			else {
				sid->set_chip_model(MOS6581);
			}
			*/
		}
	}

	extern "C++"
	template<typename T>
	int sid_fillbuffer_worker(T sid, unsigned char *tsidreg, short *ptr, int samples, const int cyc) {
		int rc = cyc / 3; // NUMVOICE
		int tdelta;
		int tdelta2;
		int result = 0;
		int total = 0;
		int c;

		tdelta = clockrate * samples / samplerate;
		
		for (c = 0; c < NUMSIDREGS; c++) {
			unsigned char o = sidorder[c];
			
			// Extra delay per music routine iteration
			if (cyc > 0 &&
				((c == 0) || (c == 7) || (c == 14))) {
				tdelta2 = rc;
				result = sid->clock(tdelta2, ptr, samples);
				total += result;
				ptr += result;
				samples -= result;
				tdelta -= rc;
			}
			sid->write(o, tsidreg[o]);
			tdelta2 = SIDWRITEDELAY;
			result = sid->clock(tdelta2, ptr, samples);
			total += result;
			ptr += result;
			samples -= result;
			tdelta -= SIDWRITEDELAY;
		}
		result = sid->clock(tdelta, ptr, samples);
		total += result;
		return total;
	}

	int sid_fillbuffer(short *ptr, int samples, const int cyc) {
		if(usefp) {
			return sid_fillbuffer_worker(sidfp[0], sidreg[0], ptr, samples, cyc);
		}
		else return sid_fillbuffer_worker(sid, sidreg[0], ptr, samples, cyc);
	}

	int sid_fillbuffer_stereo(short *left, short *right, int samples, const int cyc) {
		int total1, total2;
		total1 = sid_fillbuffer_worker(sidfp[0], sidreg[0], left, samples, cyc);
		total2 = sid_fillbuffer_worker(sidfp[1], sidreg[1], right, samples, cyc);
		assert(total1 == total2);
		return total1;
	}
	
	float* get_sample_buf() {
		return sidfp[0]->sample; // FIXME
	}
}
