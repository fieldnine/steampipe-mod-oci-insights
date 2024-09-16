dashboard "vcn_load_balancer" {

  title         = "OCI VCN Load Balancer"

  tags = merge(local.vcn_common_tags, {
    type = "Detail"
  })

  input "load_balancer_id" {
    title = "Select a security group:"
    query = query.vcn_load_balancer_input
    width = 4
  }

  container {

    container {

      table {
        title = "Dashboard"
        query = query.vcn_load_balancer_dashboard
        type  = "column"

      }

      table {
        title = "Overview"
        type  = "line"
        width = 6
        query = query.vcn_load_balancer_overview
        args  = [self.input.load_balancer_id.value]

      }

      table {
        title = "Tags"
        width = 6

        query = query.vcn_load_balancer_tag
        args  = [self.input.load_balancer_id.value]

      }

    }

  }

}

# Input queries

query "vcn_load_balancer_input" {
  sql = <<-EOQ
    select
      g.display_name as label,
      g.id as value,
      json_build_object(
        'b.id', right(reverse(split_part(reverse(g.id), '.', 1)), 8),
        'g.region', region,
        'oci.name', coalesce(oci.title, 'root'),
        't.name', t.name
      ) as tags
    from
      oci_core_load_balancer as g
      left join oci_identity_compartment as oci on g.compartment_id = oci.id
      left join oci_identity_tenancy as t on g.tenant_id = t.id
    where
      g.lifecycle_state <> 'TERMINATED'
    order by
      g.display_name;
  EOQ
}

# Other detail page queries

query "vcn_load_balancer_overview" {
  sql = <<-EOQ
    select
      display_name as "Name",
      time_created as "Time Created",
      region as "Region",
      id as "OCID",
      compartment_id as "Compartment ID"
    from
      oci_core_load_balancer
    where
      id = $1 and lifecycle_state <> 'TERMINATED';
  EOQ
}

query "vcn_load_balancer_tag" {
  sql = <<-EOQ
    with jsondata as (
      select
        tags::json as tags
      from
        oci_core_load_balancer
      where
        id = $1 and lifecycle_state <> 'TERMINATED'
    )
    select
      key as "Key",
      value as "Value"
    from
      jsondata,
      json_each_text(tags)
    order by
      key;
  EOQ
}


# Dashboard queries
query "vcn_load_balancer_dashboard" {
  sql = <<-EOQ
      select
        s.display_name as "Name",
        t.title as "Tenancy",
        p.title as "Parent Compartment",
        coalesce(c.title, 'root') as "Compartment",
        value ->> 'name' as "listener_name",
        value ->> 'port' as "listener_port",
        value ->> 'protocol' as "listener_protocol",
        value ->> 'defaultBackendSetName' as "listener_backend",
        value ->> 'sslConfiguration' as "listener_ssl",
        case
          when l.is_enabled is null
          or not l.is_enabled then null
          else 'Enabled'
        end as "Logs Status",
        l.configuration -> 'source' ->> 'category' as "Log_type",
        l.tags -> 'CreatedBy' as "Log_Created_by",
        l.tags -> 'managed_by' as "Log_Managed_by",
        s.region as "Region",
        s.id as "OCID"
      from
        oci_core_load_balancer as s
        left join oci_logging_log as l on s.id = l.configuration -> 'source' ->> 'resource'
        left join oci_identity_compartment as c on s.compartment_id = c.id
        left join oci_identity_compartment as p on c.compartment_id = p.id
        left join oci_identity_tenancy as t on s.tenant_id = t.id,
        jsonb_each(s.listeners)
      where
        s.lifecycle_state <> 'TERMINATED'
      order by
        s.display_name;
  EOQ
}