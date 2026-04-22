using UnityEngine;

public static class WavUtility
{
    public static AudioClip ToAudioClip(byte[] wavData, string name)
    {
        int sampleCount = wavData.Length / 2;
        float[] audioData = new float[sampleCount];

        for (int i = 0; i < sampleCount; i++)
        {
            short sample = System.BitConverter.ToInt16(wavData, i * 2);
            audioData[i] = sample / 32768f;
        }

        AudioClip clip = AudioClip.Create(name, sampleCount, 1, 44100, false);
        clip.SetData(audioData, 0);
        return clip;
    }
}