test "writer preserves exact decimals and deletion" {
 let t : Table = { fields:[{name:"AMOUNT",kind:Numeric,width:12,decimals:4},{name:"DATE",kind:Date,width:8,decimals:0}], rows:[{deleted:true,values:[Number("-0.1200"),DateValue("20000229")]}] }
 assert_eq(read(write(t)),t)
}
test "writer refuses invalid century leap date" {
 let t : Table = { fields:[{name:"DATE",kind:Date,width:8,decimals:0}], rows:[{deleted:false,values:[DateValue("19000229")]}] }
 let rejected = try { ignore(write(t)); false } catch { _ => true }
 assert_true(rejected)
}
