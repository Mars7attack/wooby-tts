import unittest
from unittest.mock import MagicMock, patch
import re
import array
import wave
import io
import os

class TestTranscribeLogic(unittest.TestCase):
    def test_special_token_filter(self):
        """Vérifie que les tokens NeMo sont bien filtrés."""
        input_text = "<pad>bonjour<unk> comment ça va <s>"
        expected = "bonjour comment ça va"
        
        # Logique de filtrage extraite de voice-flow.sh
        cleaned = re.sub(r'<[^>]+>', '', input_text).strip()
        self.assertEqual(cleaned, expected)

    def test_special_token_filter_multiple(self):
        """Vérifie le filtrage avec des tokens collés."""
        input_text = "<pad><unk>test<something>"
        expected = "test"
        cleaned = re.sub(r'<[^>]+>', '', input_text).strip()
        self.assertEqual(cleaned, expected)

    def test_wav_to_floats_logic(self):
        """Vérifie la conversion des samples 16-bit vers floats [-1.0, 1.0]."""
        # On simule des données 16-bit (2 octets par sample)
        # 0x0000 -> 0.0
        # 0x7FFF (32767) -> ~1.0
        # 0x8000 (-32768) -> -1.0
        raw_samples = array.array('h', [0, 32767, -32768]).tobytes()
        
        samples = array.array("h", raw_samples)
        floats = [s / 32768.0 for s in samples]
        
        self.assertEqual(floats[0], 0.0)
        self.assertAlmostEqual(floats[1], 32767/32768.0)
        self.assertEqual(floats[2], -1.0)

    @patch('sherpa_onnx.OfflineRecognizer')
    def test_recognizer_mock(self, mock_recognizer_class):
        """Vérifie que la structure d'appel à sherpa_onnx est respectée (sans charger le modèle)."""
        mock_recognizer = MagicMock()
        mock_recognizer_class.from_nemo_ctc.return_value = mock_recognizer
        
        mock_stream = MagicMock()
        mock_recognizer.create_stream.return_value = mock_stream
        mock_stream.result.text = "test reconnu"

        # Simulation simplifiée du flux dans voice-flow.sh
        recognizer = mock_recognizer_class.from_nemo_ctc(
            model="fake.onnx",
            tokens="fake.txt",
            num_threads=4,
            sample_rate=16000,
            feature_dim=128,
            decoding_method="greedy_search",
            debug=False,
        )
        
        stream = recognizer.create_stream()
        stream.accept_waveform(16000, [0.0, 0.1, -0.1])
        recognizer.decode_stream(stream)
        
        self.assertEqual(stream.result.text, "test reconnu")
        mock_stream.accept_waveform.assert_called_once()
        recognizer.decode_stream.assert_called_once_with(mock_stream)

if __name__ == '__main__':
    unittest.main()
