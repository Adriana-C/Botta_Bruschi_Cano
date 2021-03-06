module powerEnJoy

/***********************PowerEnJoyContainer*********************/
one sig PowerEnJoyContainer{
	users: set User,
	reservations: set Reservation,
	operators: some FieldOperator
}{
	users=User
	reservations=Reservation
	operators=FieldOperator
}
/*****************************USER****************************/
sig User{
	userID: UserID,
	searches: set CarSearch,
	reserves: set Reservation
}{
	#reserves <= #searches
}

abstract sig ID {}

sig UserID extends ID{}
sig OperatorID extends ID{}

/**************************CAR***********************************/
sig Car{
	plate: Int,
	state: CarState,
	locked: CarLocking,
	location: Area
}{
	plate>0
}

abstract sig State{}
abstract sig CarState extends State{}

sig Available extends CarState{}
sig Reserved extends CarState{}
sig Maintenance extends CarState{}
sig InUse extends CarState{}
sig Pending extends CarState{}

abstract sig CarLocking extends State {}

sig Locked extends CarLocking{}
sig UnLocked extends CarLocking{}
sig TempLocked extends CarLocking{}

sig ChargingPoint{}{
	ChargingPoint=SafeArea.chargingPoint
}

abstract sig Area {
	coordinates: some Position
}

sig OtherArea extends Area{}
sig SafeArea extends Area{
	chargingPoint: lone ChargingPoint
}


/**********************Reservation*********************************/
sig Reservation{
	resID: Int,
	state: ReservationState,
	car: Car

}{
		resID>0
}

abstract sig ReservationState extends State{} 

sig Valid extends ReservationState{}
sig Confirmed extends ReservationState{}
sig Frozen extends ReservationState{}
sig Completed extends ReservationState{}
sig Cancelled extends ReservationState{}

/****************************CarSearch****************************/

sig CarSearch{
	firstRange: FirstRange,
	secondRange: SecondRange,
	thirdRange: ThirdRange,
	address: Position,
	reserve: lone Reservation
}

sig Position{}

abstract sig Range{
	coverage: some Position,
	centralPosition: Position,
	cars: set Car,
	radius:  one Int	
}

sig FirstRange extends Range{
}{
	int radius=1}

sig SecondRange extends Range{
}{
	int radius=2}
sig ThirdRange extends Range{
}{
	int radius=4}

/****************************FieldOperator************************/
sig FieldOperator{
	operatorID: OperatorID,
	handling: lone Car
}

/******************************FACTS***************************/
fact userProperties{
	//Unique ID for every user
	all disjoint u1, u2: User | u1.userID!=u2.userID
	//A user can't have two different reservations going on at the same time
	all u: User {no disjoint r1,r2: Reservation| hasReserved[u, r1] &&  hasReserved[u, r2] &&
																r1.state in Valid + Confirmed && r2.state in Valid +Confirmed }
}
fact uniquePlates{
	no disj c1,c2: Car | c1.plate=c2.plate
}
fact ids{
	no disjoint fo1,fo2: FieldOperator | fo1.operatorID=fo2.operatorID
}

fact locations{
	//Two cars can not be in the same area at the same time
	no disj c1,c2: Car | c1.location=c2.location
	//The cars in a search result are all centered in the requested address
	all s: CarSearch | s.address=s.firstRange.centralPosition + s.secondRange.centralPosition +s.thirdRange.centralPosition 
	all disjoint s1,s2: SafeArea{no cp: ChargingPoint | cp in s1.chargingPoint && cp in s2.chargingPoint}
	all disjoint a1,a2: Area {no p1: Position | p1 in a1.coordinates && p1 in a2.coordinates}


}

fact reservationProperties{
	//Unique reservation number for each reservation
	no disjoint r1,r2: Reservation | r1.resID=r2.resID
	//For every reservation there exists a search that led to it
	all r: Reservation {one s: CarSearch |  searchTurnedReservation[s,r]}
	//The search and the reservation in a association have the same qualities
	all r: Reservation{one s: CarSearch| one u: User |hasReserved[u,r] && hasSearched[u,s] &&  carBelongsToSearch[r.car, s] }																																
	//A reservation is done only by one user
	all r: Reservation {one u: User | hasReserved[u,r]}
}

fact reservationStatePropertie{
	//A reservation is valid the instance after is being created until the car is unlocked by the reservee or until the reservation is cancelled
	all r: Reservation | r.state in Valid <=> r.car.state in Reserved && r.car.locked in Locked && r.car.location in SafeArea

	//A reservation is Confirmed the moment the reservee unlocks said car
	all r: Reservation | r.state in Confirmed <=> r.car.state in InUse && r.car.locked in UnLocked && r.car.location in OtherArea

	//After a user is done with the car, the car can be in two types of conditions: Low battery, with mainatance problems so in Maintance 
	// or the user has a stellar behavior and the car is Available for yet another reservation	
	all r: Reservation | r.state in Completed <=> r.car.state in Maintenance + Available  && r.car.locked in Locked && r.car.location in SafeArea

	//A reservation is Canceled if the user doesn't pick up the car in time or if the user himself/herself canceles the reservation
	all r: Reservation | r.state in Cancelled <=> r.car.state in Available && r.car.locked in Locked && r.car.location in SafeArea

	//A reservation is Frozen if the user decides to make a stop but is not done with his/her reservation
	all r: Reservation | r.state in Frozen <=> r.car.state in Pending && r.car.locked in TempLocked && r.car.location in SafeArea + OtherArea
}

fact generalFacts{
	Car= Reservation.car +FirstRange.cars + SecondRange.cars +ThirdRange.cars
	ReservationState= Reservation.state
	Area=Car.location
	CarState=Car.state
	CarLocking=Car.locked
	CarSearch=User.searches
	Reservation=User.reserves
	User=PowerEnJoyContainer.users
	FirstRange=CarSearch.firstRange
	SecondRange=CarSearch.secondRange
	ThirdRange=CarSearch.thirdRange
	UserID=User.userID
	OperatorID=FieldOperator.operatorID
	FirstRange.coverage in SecondRange.coverage
	SecondRange.coverage in ThirdRange.coverage
	Position= FirstRange.coverage + SecondRange.coverage + ThirdRange.coverage + Area.coordinates
	CarState=Available + InUse + Pending + Reserved + Maintenance
	CarLocking=Locked + UnLocked + TempLocked
	ReservationState= Valid + Confirmed + Completed + Cancelled + Frozen
	ChargingPoint=SafeArea.chargingPoint
	
}

fact carStateProperties{
	//An available car is a car that appears on the searches the user can make and it is locked
	all c: Car{c.state in Available => {no r: Reservation | r.car=c }}
//	all c: Car {c.state in Available <=> c in FirstRange.cars + SecondRange.cars + ThirdRange.cars }
	all c: Car {c.state in Available =>c.locked in Locked 
														&& c in FirstRange.cars + SecondRange.cars + ThirdRange.cars 
														&& c.location in SafeArea}
	all c: Car{c.state in Available => no fo: FieldOperator | c in fo.handling}
	//	A car is Reserved if there is a user that has reserves it. A reserved car is still Locked
	all c: Car { c.state in Reserved => {one r: Reservation|r.car=c && r.state in Valid }}
	all c: Car { c.state in Reserved =>c.locked in Locked  
															&& c.location in SafeArea
															 }
	all c: Car{c.state in Reserved => no fo: FieldOperator | c in fo.handling}
	//A car is in use if there exists a confirmed reservation, the car in unlocked and not located in a SafeArea
	all c: Car { c.state in InUse <=> {one r: Reservation | r.car=c && r.state in Confirmed 
																									&& c.locked in UnLocked
																									&& c.location in OtherArea  }}
	all c: Car{c.state in InUse => no fo: FieldOperator | c in fo.handling}
	//A car is Pending if the reservee makes a stop but the reservation is ongoing. He can park the car in a non Safe area. 
	all c: Car{c.state in Pending <=>{one r: Reservation |  c.locked in TempLocked 
																						&& r.car=c && r.state in Frozen}}
	all c: Car{c.state in Pending => no fo: FieldOperator | c in fo.handling}
	//A car is said to be in maintanance if it 
	all c: Car {c.state in Maintenance => {no r: Reservation |r.car=c  }}
	all c: Car {c.state in Maintenance => {some fo: FieldOperator | c in fo.handling } || #c.location.chargingPoint=1}
	all c: Car {c.state in Maintenance =>	c.location in SafeArea && c.locked in UnLocked }
	all c: Car{c.state in Maintenance  => c not in  FirstRange.cars + SecondRange.cars + ThirdRange.cars  }

	all c: Car{c.location in SafeArea && #c.location.chargingPoint=1 => c.state in Maintenance}
	all c: Car{c not in  FirstRange.cars + SecondRange.cars + ThirdRange.cars => c.state in Maintenance  + Reserved + InUse + Pending}


}

fact rangeProp{
	all s: CarSearch {all c: Car | c in s.firstRange.cars <=> c.location.coordinates in s.firstRange.coverage }
	all s: CarSearch {all c: Car | c in s.secondRange.cars <=> c.location.coordinates in s.secondRange.coverage }
	all s: CarSearch {all c: Car | c in s.thirdRange.cars <=> c.location.coordinates in s.thirdRange.coverage }
}



/**************************PREDICATES**************************/ 

pred hasReserved [u: User, r: Reservation]{
	r in u.reserves
}

pred hasSearched[u: User, s: CarSearch]{
	s in u.searches
}
pred searchTurnedReservation[s: CarSearch, r: Reservation]{
	r in s.reserve
}

pred carBelongsToSearch[c: Car, s: CarSearch]{
	c in s.firstRange.cars +s.secondRange.cars + s.thirdRange.cars 
}

pred addUser[c,c': PowerEnJoyContainer, u: User]{
	c'.users=c.users + u
	c'.operators=c.operators
	c'.reservations=c.reservations
}

pred addOperator[c,c': PowerEnJoyContainer, o: FieldOperator, s: set CarSearch]{
	c'.operators=c.operators + o
	c'.users=c.users
	c'.reservations=c.reservations
}

pred addReservation[c,c': PowerEnJoyContainer, u,u': User, r: Reservation]{
	r.state in Valid
	c'.users=c.users
	c'.reservations=c.reservations + r
	u'.reserves=u.reserves + r
}

assert reservationCheck{
	no r: Reservation {no s: CarSearch| searchTurnedReservation[s,r]}
	no r: Reservation { one c: Car | r.car=c && c.state in Maintenance}
	all r: Reservation {no c: Car | r.car=c && r.state in Completed && c.state not in Available}
	all r: Reservation {no c: Car | r.car=c && r.state in Cancelled && c.state not in Available}
	all r: Reservation {no c: Car | r.car=c && r.state in Confirmed && c.state not in InUse}
	all r: Reservation {no c: Car | r.car=c && r.state in Valid && c.state not in Reserved}
	all r: Reservation {no c: Car | r.car=c && r.state in Frozen && c.state not in Pending}
}

assert carCheck{
	no c: Car {one r: Reservation | c.location in SafeArea && r.car=c && r.state in Confirmed}
	no c: Car | c.state in Available && c.locked in UnLocked + TempLocked
	no c: Car | c.state in Reserved && c.locked in UnLocked + TempLocked
	no c: Car | c.state in InUse && c.locked in Locked + TempLocked
	no c: Car | c.state in Maintenance && c.locked in Locked + TempLocked
	no c: Car | c.state in Pending && c.locked in UnLocked + Locked
	no c: Car | c.location in OtherArea && c.locked in Locked
	no c: Car | c.state in Maintenance  && c in FirstRange.cars + SecondRange.cars + ThirdRange.cars
}


pred show{
	#User=2
	#User.searches=3
	#User.reserves=1
	
}

run show 
run addUser for 2
run addReservation for 3
run addOperator for 2
check reservationCheck for 3
check carCheck for 3
