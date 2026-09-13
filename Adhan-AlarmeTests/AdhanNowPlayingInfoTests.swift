import Foundation
import MediaPlayer
import Testing

@testable import Adhan_Alarme

struct AdhanNowPlayingInfoTests {
    @Test func playingIncludesTitleRateAndDuration() {
        let info = AdhanNowPlayingInfo.dictionary(title: "Adhan – Makkah", duration: 180, isPlaying: true)
        #expect(info[MPMediaItemPropertyTitle] as? String == "Adhan – Makkah")
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1.0)
        #expect(info[MPMediaItemPropertyPlaybackDuration] as? Double == 180)
        let artist = info[MPMediaItemPropertyArtist] as? String
        #expect(artist?.isEmpty == false)
    }

    @Test func pausedSetsZeroRate() {
        let info = AdhanNowPlayingInfo.dictionary(title: "Adhan – Makkah", duration: 180, isPlaying: false)
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 0.0)
    }

    @Test func invalidDurationsAreOmitted() {
        let durations: [Double?] = [nil, 0, -5, Double.nan, Double.infinity]
        for duration in durations {
            let info = AdhanNowPlayingInfo.dictionary(title: "T", duration: duration, isPlaying: true)
            #expect(info[MPMediaItemPropertyPlaybackDuration] == nil)
        }
    }
}
