package hse.adapter

import hse.adapter.dto.AnalyzeMatchRequest
import org.springframework.cloud.openfeign.FeignClient
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody

@FeignClient("engine")
interface GameEngineAdapter {

    @PostMapping("game-engine/analyze")
    fun getAnalysis(@RequestBody request: AnalyzeMatchRequest): Map<Any, Any>
}