//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


protocol InstrumentBuilder {
    var meterProviderSharedState : MeterProviderSharedState { get }
    var meterSharedState : StableMeterSharedState { get set }
    var type : InstrumentType { get }
    var valueType : InstrumentValueType { get }
    var description : String { get set }
    var unit : String { get set }
    var instrumentName : String { get }
}
extension InstrumentBuilder {
    mutating func setUnit(_ units: String) -> Self {
        // todo : validate unit 
        self.unit = unit
        return self
    }
    
    mutating func setDescription(_ description: String) -> Self {
        self.description = description
        return self
    }
    
    func swapBuilder<T : InstrumentBuilder>(_ builder : (MeterProviderSharedState, StableMeterSharedState, String, String, String )->T) ->T {
        return builder(meterProviderSharedState, meterSharedState, instrumentName, description, unit  )
    }
    
    
    // todo : Is it necessary to use inout for writableMetricStorage?
    func buildSynchronousInstrument<T : Instrument>(_ instrumentFactory: (InstrumentDescriptor, inout WritableMetricStorage) -> T) ->  T {
        let descriptor = InstrumentDescriptor(name: instrumentName, description: description, unit: unit, type: type, valueType: valueType)
        var storage = meterSharedState.registerSynchronousMetricStorage(instrument: descriptor, meterProviderSharedState: meterProviderSharedState)
        return instrumentFactory(descriptor,&storage)
        
    }
    
    func registerDoubleAsynchronousInstrument(type : InstrumentType, updater: @escaping (ObservableDoubleMeasurement)-> Void) -> ObservableInstrumentSdk {
        let sdkObservableMeasurement = buildObservableMeasurement(type: type)
        let callbackRegistration = CallbackRegistration.init(observableMeasurements: [sdkObservableMeasurement]) {
            updater(sdkObservableMeasurement)
        }
        meterSharedState.registerCallback(callback: callbackRegistration)
        return ObservableInstrumentSdk(meterSharedState: meterSharedState, callbackRegistration: callbackRegistration)
    }
    
    func registerLongAsynchronousInstrument(type: InstrumentType, updater: @escaping (ObservableLongMeasurement)->Void ) -> ObservableInstrumentSdk {
        let sdkObservableMeasurement = buildObservableMeasurement(type: type)
        let callbackRegistration = CallbackRegistration(observableMeasurements: [sdkObservableMeasurement], callback: {
            updater(sdkObservableMeasurement)
        })
        meterSharedState.registerCallback(callback: callbackRegistration)
        return ObservableInstrumentSdk(meterSharedState: meterSharedState, callbackRegistration: callbackRegistration)
    }
    
    func buildObservableMeasurement(type: InstrumentType) -> StableObservableMeasurementSdk {
        let descriptor = InstrumentDescriptor(name: instrumentName, description: description, unit: unit, type: type, valueType: valueType)
        return meterSharedState.registerObservableMeasurement(instrumentDescriptor: descriptor)
    }
}
