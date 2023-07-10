async function main() {
  const EventTicketing = await ethers.getContractFactory("EventTicketing");

  // add constructor parameters here
  const maxTickets = 100;  // replace with your value
  const eventLocation = "My Event Location";  // replace with your value
  const eventName = "My Event";  // replace with your value
  const eventTime = Math.floor(1703484000);  // replace with your value (in UNIX timestamp)

  const eventTicketing = await EventTicketing.deploy(maxTickets, eventLocation, eventName, eventTime);
  console.log(eventTicketing)
  console.log("EventTicketing deployed to:", eventTicketing.target);
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});