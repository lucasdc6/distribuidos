variable "instance_count" {
    type        = number
    description = "Cantidad de instancias a crear"
}

variable "vpc_id" {
    type        = string
    description = "ID de la VPC a usar por las instancias"
}

variable "subnet_id" {
    type        = string
    description = "ID de la subred a usar por las instancias"
}

variable "key_name" {
    type        = string
    description = "Nombre del par de claves SSH a usar para conectarse a la instancias. Seran requeridos posteriormente por ansible"
}

variable "ip_ingress_ips" {
    type        = list(string)
    default     = ["0.0.0.0/0"]
    description = "Listado de IPs admitidas para conectarse por SSH. Se recomienda cerrar a la IP propia. Ver http://ipconfig.me/"
}