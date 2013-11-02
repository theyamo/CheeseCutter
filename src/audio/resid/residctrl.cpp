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
	unsigned char sidreg[NUMSIDREGS];
	const unsigned char sidorder[] = {
        0x0e,0x0f,0x14,0x13,0x10,0x11,0x12,
        0x07,0x08,0x0d,0x0c,0x09,0x0a,0x0b,
        0x00,0x01,0x06,0x05,0x02,0x03,0x04,
        0x16,0x17,0x18,0x15
	};
	SID *sid= 0;
	SIDFP *sidfp = 0;
	int residdelay = 0;
	int usefp = 0;

	void sid_close() {
		if(sid) delete sid;
		if(sidfp) delete sidfp;
	}
	
	void sid_init(int fp, FILTERPARAMS *fparams, int speed, unsigned m, unsigned ntsc, unsigned interpolate, unsigned customclockrate)
	{
		int c;

		usefp = fp;
		
		if (ntsc) clockrate = NTSCCLOCKRATE;
		else clockrate = PALCLOCKRATE;
	
		if (customclockrate)
			clockrate = customclockrate;
	
		samplerate = speed;
	
		if (!sidfp) sidfp = new SIDFP();
		if (!sid) sid = new SID();
		
		if(usefp) {
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
			for (c = 0; c < NUMSIDREGS; c++) {
				sidreg[c] = 0x00;
			}

			if (m == 1)
				sidfp->set_chip_model(MOS8580);
			else
				sidfp->set_chip_model(MOS6581);
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
		else {
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
			for (c = 0; c < NUMSIDREGS; c++) {
				sidreg[c] = 0x00;
			}
  
			if (m == 1) {
				sid->set_chip_model(MOS8580);
			}
			else {
				sid->set_chip_model(MOS6581);
			}
		}
	}
  
	unsigned char sid_getorder(unsigned char index) {
		return sidorder[index];
	}
	
	int sid_fillbuffer(short *ptr, int samples, const int cyc) {
		int os = samples;
		int rc = cyc / 3; // NUMVOICE
		int badline = rand() % NUMSIDREGS;
		int tdelta;
		int tdelta2;
		int result;
		int total = 0;
		int c;

		tdelta = clockrate * samples / samplerate;
		
		for (c = 0; c < NUMSIDREGS; c++) {
			unsigned char o = sid_getorder(c);
			
			// Extra delay per music routine iteration
			if (cyc > 0 &&
				((c == 0) || (c == 7) || (c == 14))) {
				tdelta2 = rc;
				if(usefp)
					result = sidfp->clock(tdelta2, ptr, samples);
				else
					result = sid->clock(tdelta2, ptr, samples);
				total += result;
				ptr += result;
				samples -= result;
				tdelta -= rc;
			}
			
			// Possible random badline delay once per writing
			/*
			if ((badline == c) && (residdelay)) {
				tdelta2 = residdelay;
				result = sid->clock(tdelta2, ptr, samples);
				total += result;
				ptr += result;
				samples -= result;
				tdelta -= residdelay;
			}
			*/
			if(usefp)
				sidfp->write(o, sidreg[o]);
			else
				sid->write(o, sidreg[o]);
		
			tdelta2 = SIDWRITEDELAY;
			if(usefp)
				result = sidfp->clock(tdelta2, ptr, samples);
			else
				result = sid->clock(tdelta2, ptr, samples);
			total += result;
			ptr += result;
			samples -= result;
			tdelta -= SIDWRITEDELAY;
		}

		if(usefp)
			result = sidfp->clock(tdelta, ptr, samples);
		else
			result = sid->clock(tdelta, ptr, samples);
		
		total += result;
		if(total > os) abort();
		assert(total <= os);
		return total;
	}
}
