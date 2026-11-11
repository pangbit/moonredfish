///|
/// Follows ServiceRoot.Tasks. Reading a service never starts or polls a task.
pub async fn Client::task_service(
  self : Client,
  root : Resource,
) -> Field[TaskService] {
  match self.linked_resource(root, "Tasks") {
    Missing => Missing
    Null => Null
    Value(resource) => Value(resource.task_service())
  }
}

///|
/// Reads the advertised TaskService.Tasks collection once.
pub async fn Client::tasks(
  self : Client,
  service : Resource,
) -> Field[Array[Task]] {
  match self.linked_members(service, "Tasks") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::task))
  }
}

///|
/// Reads Task.SubTasks without recursively traversing descendants or TaskMonitor.
pub async fn Client::sub_tasks(
  self : Client,
  task : Resource,
) -> Field[Array[Task]] {
  match self.linked_members(task, "SubTasks") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::task))
  }
}

///|
/// Reads only resources already advertised in Task.Links.CreatedResources.
pub async fn Client::task_created_resources(
  self : Client,
  task : Resource,
) -> Field[Array[Resource]] {
  let paths = match read_field(task.json, "Links", object_value) {
    Missing => Missing
    Null => Null
    Value(links) => read_array(links, "CreatedResources", link_uri)
  }
  self.read_link_array(paths, resource => resource)
}
